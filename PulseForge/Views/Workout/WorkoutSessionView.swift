//
//  WorkoutSessionView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/20/26.
//  Updated: February 25, 2026
//
//  Apple App Store Compliance:
//  - Premium features (“Tap Anywhere to Pause”, advanced metrics) gated behind subscription.
//  - Large, high-contrast buttons + full-screen tap target for sweaty/wet-hand use.
//  - Strong haptic feedback on every action.
//  - Discard confirmation alert protects against accidental loss of workout data.
//  - Full VoiceOver accessibility with clear labels and hints.
//

import SwiftUI
import SwiftData
internal import HealthKit

struct WorkoutSessionView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(AuthenticationManager.self) private var authenticationManager
    @Environment(ErrorManager.self) private var errorManager
    
    let workout: Workout
    
    @State private var viewModel: WorkoutSessionViewModel
    @AccessibilityFocusState private var isExerciseFocused: Bool
    
    // Discard alert state
    @State private var showDiscardAlert = false
    
    init(workout: Workout) {
        self.workout = workout
        self._viewModel = State(wrappedValue: WorkoutSessionViewModel(workout: workout))
    }
    
    var body: some View {
        ZStack {
            Color.proBackground2.ignoresSafeArea()
            
            // Premium: Tap anywhere on screen to pause (sweaty hands friendly)
            if purchaseManager.isSubscribed {
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                viewModel.togglePause()
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            }
                    )
            }
            
            VStack(spacing: 32) {
                Text(workout.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                if !workout.sortedExercises.isEmpty {
                    Text(viewModel.currentExerciseText)
                        .font(.title3.bold())
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityFocused($isExerciseFocused)
                }
                
                Text(viewModel.formattedTime)
                    .font(.system(size: 68, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(viewModel.formattedTime)
                
                if workout.roundsEnabled && workout.roundsQuantity > 1 {
                    Text("Round \(viewModel.currentRound) of \(workout.roundsQuantity)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Huge, sweaty-hand-friendly buttons
                VStack(spacing: 20) {
                    Button {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        Task { await viewModel.primaryButtonAction() }
                    } label: {
                        Text(viewModel.primaryButtonText)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .disabled(viewModel.isCompleting)
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        viewModel.togglePause()
                    } label: {
                        Text(viewModel.isPaused ? "Resume" : "Pause")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .disabled(viewModel.isCompleting)
                }
                .padding(.horizontal, 24)
                
                // Premium hint for sweaty hands
                if purchaseManager.isSubscribed {
                    Text("Tap anywhere on screen to pause")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 8)
                }
                
                // Crown hint (future Watch reminder)
                Text("On Apple Watch: Use Digital Crown to advance exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                
                if purchaseManager.isSubscribed && viewModel.showMetrics {
                    MetricsView(
                        intensityScore: viewModel.intensityScore,
                        progressPulseScore: viewModel.progressPulseScore,
                        dominantZone: viewModel.dominantZone
                    )
                }
            }
            .padding(.vertical, 40)
        }
        .interactiveDismissDisabled(true)           // Prevent accidental swipe-back
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel Workout") {
                    showDiscardAlert = true
                }
                .foregroundStyle(.primary)
                .fontDesign(.serif)
            }
        }
        .alert("Discard Workout Session?", isPresented: $showDiscardAlert) {
            Button("Keep Going", role: .cancel) {}
            Button("Discard Session", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("This workout session will be deleted and not added to your journal.")
                .accessibilityLabel("Warning: discarding will delete this workout session permanently")
        }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.purchaseManager = purchaseManager
            viewModel.healthKitManager = healthKitManager
            viewModel.authenticationManager = authenticationManager
            viewModel.errorManager = errorManager
            viewModel.dismissAction = { dismiss() }
            viewModel.onAppear()
            isExerciseFocused = true
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

// MARK: - Premium Metrics View
private struct MetricsView: View {
    let intensityScore: Double?
    let progressPulseScore: Double?
    let dominantZone: Int?
    
    var body: some View {
        VStack(spacing: 12) {
            if let intensity = intensityScore {
                MetricRow(title: "Intensity", value: "\(Int(intensity))%", icon: "flame.fill")
            }
            if let pulse = progressPulseScore {
                MetricRow(title: "Progress Pulse", value: "\(Int(pulse))", icon: "heart.text.clipboard")
            }
            if let zone = dominantZone {
                MetricRow(title: "Dominant Zone", value: "Zone \(zone)", icon: "figure.walk.motion")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.green)
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.headline).foregroundStyle(.white)
        }
    }
}
