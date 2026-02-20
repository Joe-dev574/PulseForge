//
//  WorkoutSessionView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/20/26.
//
//  Apple App Store Compliance:
//  - Premium metrics are gated behind subscription.
//  - Timer uses simple Foundation.Timer (no Combine).
//  - UI designed for seamless parity with future Apple Watch app.
//  - Full VoiceOver accessibility support.
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
    
    init(workout: Workout) {
        self.workout = workout
        self._viewModel = State(wrappedValue: WorkoutSessionViewModel(workout: workout))
    }
    
    var body: some View {
        ZStack {
            Color.proBackground2.ignoresSafeArea()
            
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
                
                VStack(spacing: 16) {
                    Button {
                        Task { await viewModel.primaryButtonAction() }
                    } label: {
                        Text(viewModel.primaryButtonText)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(viewModel.isCompleting)
                    
                    Button {
                        viewModel.togglePause()
                    } label: {
                        Text(viewModel.isPaused ? "Resume" : "Pause")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(viewModel.isCompleting)
                }
                .padding(.horizontal)
                
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
