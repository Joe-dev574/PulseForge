//
//  WatchWorkoutSessionView.swift
//  PulseForge watchOS
//
//  Created by Joseph DeWeese on 3/1/26.
//
//  Watch-optimized workout session that reuses WorkoutSessionViewModel.
//  Mirrors the iOS WorkoutSessionView experience adapted for the smaller display.
//
//  Features:
//  - Large centered timer with zone-aware color
//  - Current exercise name + progress index
//  - Round progress bar (if rounds enabled)
//  - Live heart rate (premium)
//  - Next Exercise / Complete Workout button
//  - Pause / Resume button
//  - Digital Crown rotation to advance exercises
//  - WatchKit haptics
//  - Discard confirmation alert
//

import SwiftUI
import SwiftData
internal import HealthKit
import WatchKit

struct WatchWorkoutSessionView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(AuthenticationManager.self) private var authenticationManager
    @Environment(ErrorManager.self) private var errorManager
    
    // MARK: - Properties
    
    let workout: Workout
    
    @State private var viewModel: WorkoutSessionViewModel
    @State private var showDiscardAlert = false
    @State private var crownValue: Double = 0.0
    @State private var lastCrownExerciseIndex: Int = 0
    
    // MARK: - Theme
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    private var themeColor: Color { Color(hex: selectedThemeColorData) ?? .blue }
    
    // MARK: - Zone Colors
    
    private var zoneColor: Color {
        guard purchaseManager.isSubscribed else { return .green }
        switch viewModel.dominantZone {
        case 1:  return .teal
        case 2:  return .green
        case 3:  return .yellow
        case 4:  return .orange
        case 5:  return .red
        default: return .green
        }
    }
    
    private var timerColor: Color {
        viewModel.isPaused ? .white.opacity(0.35) : zoneColor
    }
    
    // MARK: - Init
    
    init(workout: Workout) {
        self.workout = workout
        self._viewModel = State(wrappedValue: WorkoutSessionViewModel(workout: workout))
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                workoutHeader
                timerSection
                exerciseSection
                roundProgressSection
                liveHeartRateSection
                pausedBanner
                controlButtons
            }
            .padding(.horizontal, 4)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    showDiscardAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert("Discard Session?", isPresented: $showDiscardAlert) {
            Button("Keep Going", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("This session will not be saved.")
        }
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: Double(max(workout.effectiveExercises.count - 1, 0)),
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            let targetIndex = Int(newValue.rounded())
            if targetIndex > lastCrownExerciseIndex
                && targetIndex <= workout.effectiveExercises.count - 1
                && viewModel.currentExerciseIndex < workout.effectiveExercises.count - 1 {
                Task { await viewModel.primaryButtonAction() }
                WKInterfaceDevice.current().play(.click)
            }
            lastCrownExerciseIndex = targetIndex
        }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.purchaseManager = purchaseManager
            viewModel.healthKitManager = healthKitManager
            viewModel.authenticationManager = authenticationManager
            viewModel.errorManager = errorManager
            viewModel.dismissAction = { dismiss() }
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
    
    // MARK: - Workout Header
    
    private var workoutHeader: some View {
        HStack(spacing: 4) {
            if let symbol = workout.category?.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(themeColor)
            }
            Text(workout.title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(themeColor)
                .tracking(1.5)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout: \(workout.title)")
    }
    
    // MARK: - Timer
    
    private var timerSection: some View {
        VStack(spacing: 2) {
            Text(viewModel.formattedTime)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(timerColor)
                .contentTransition(.numericText())
                .accessibilityLabel("Elapsed time")
                .accessibilityValue(viewModel.formattedTime)
            
            Text("ELAPSED")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(2)
        }
    }
    
    // MARK: - Exercise
    
    @ViewBuilder
    private var exerciseSection: some View {
        if !workout.sortedExercises.isEmpty {
            VStack(spacing: 3) {
                let total = workout.effectiveExercises.count
                let index = min(viewModel.currentExerciseIndex, total - 1)
                
                Text("\(index + 1) of \(total)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
                
                Text(workout.effectiveExercises[safe: index]?.name ?? "")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .accessibilityLabel("Current exercise: \(viewModel.currentExerciseText)")
            }
        }
    }
    
    // MARK: - Round Progress
    
    @ViewBuilder
    private var roundProgressSection: some View {
        if workout.roundsEnabled && workout.roundsQuantity > 1 {
            VStack(spacing: 4) {
                Text("ROUND \(viewModel.currentRound) / \(workout.roundsQuantity)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 3)
                        Capsule()
                            .fill(zoneColor)
                            .frame(
                                width: geo.size.width * min(
                                    Double(viewModel.currentRound) / Double(workout.roundsQuantity), 1.0
                                ),
                                height: 3
                            )
                            .animation(.easeInOut(duration: 0.4), value: viewModel.currentRound)
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Round \(viewModel.currentRound) of \(workout.roundsQuantity)")
        }
    }
    
    // MARK: - Live Heart Rate (Premium)
    
    @ViewBuilder
    private var liveHeartRateSection: some View {
        if purchaseManager.isSubscribed && viewModel.currentHeartRate > 0 {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.red)
                Text("\(Int(viewModel.currentHeartRate)) BPM")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .accessibilityLabel("Heart rate: \(Int(viewModel.currentHeartRate)) beats per minute")
        }
    }
    
    // MARK: - Paused Banner
    
    @ViewBuilder
    private var pausedBanner: some View {
        if viewModel.isPaused {
            HStack(spacing: 4) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 8, weight: .bold))
                Text("PAUSED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel("Workout is paused")
        }
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        VStack(spacing: 8) {
            // Primary: Next Exercise / Complete
            Button {
                WKInterfaceDevice.current().play(.click)
                Task { await viewModel.primaryButtonAction() }
            } label: {
                ZStack {
                    if viewModel.isCompleting {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 4) {
                            Text(viewModel.primaryButtonText)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            if viewModel.primaryButtonText == "Next Exercise" {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(themeColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCompleting)
            .accessibilityLabel(viewModel.primaryButtonText)
            .accessibilityHint(viewModel.primaryButtonAccessibilityHint)
            
            // Secondary: Pause / Resume
            Button {
                WKInterfaceDevice.current().play(.click)
                viewModel.togglePause()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCompleting)
            .accessibilityLabel(viewModel.isPaused ? "Resume workout" : "Pause workout")
        }
        .padding(.top, 4)
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
