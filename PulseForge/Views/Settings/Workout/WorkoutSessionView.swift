//
//  WorkoutSessionView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/20/26.
//  Updated: February 28, 2026
//
//  Apple App Store Compliance:
//  - Premium features ("Tap Anywhere to Pause", live HR, advanced metrics) gated behind subscription.
//  - Large, high-contrast buttons + full-screen tap target for sweaty/wet-hand use.
//  - Strong haptic feedback on every action.
//  - Discard confirmation alert protects against accidental loss of workout data.
//  - Full VoiceOver accessibility with clear labels and hints.
//  - Animations respect `.reduceMotion` accessibility setting.
//

import SwiftUI
import SwiftData
internal import HealthKit

struct WorkoutSessionView: View {

    // MARK: - Environment

    @Environment(\.dismiss)                   private var dismiss
    @Environment(\.modelContext)              private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PurchaseManager.self)        private var purchaseManager
    @Environment(HealthKitManager.self)       private var healthKitManager
    @Environment(AuthenticationManager.self)  private var authenticationManager
    @Environment(ErrorManager.self)           private var errorManager

    // MARK: - Properties

    let workout: Workout

    @State private var viewModel: WorkoutSessionViewModel
    @AccessibilityFocusState private var isExerciseFocused: Bool
    @State private var showDiscardAlert = false
    @State private var hrPulse          = false

    // MARK: - Theme

    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    private var themeColor: Color { Color(hex: selectedThemeColorData) ?? .blue }

    // MARK: - Zone-aware colors

    /// Reflects the dominant HR zone when subscribed; defaults to green.
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
        ZStack {
            background

            // Premium: tap anywhere to pause
            if purchaseManager.isSubscribed {
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            viewModel.togglePause()
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        }
                    )
            }

            VStack(spacing: 0) {
                workoutHeader
                Spacer()
                exerciseSection
                Spacer().frame(height: 28)
                timerSection
                Spacer().frame(height: 20)
                roundProgressSection
                liveHeartRateSection
                Spacer()
                postWorkoutMetrics
                pausedBanner
                controlButtons
                hintFooter
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .padding(.top, 16)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
        .toolbar { toolbarContent }
        .alert("Discard Workout Session?", isPresented: $showDiscardAlert) {
            Button("Keep Going", role: .cancel) {}
            Button("Discard Session", role: .destructive) { dismiss() }
        } message: {
            Text("This session will not be saved to your journal.")
                .accessibilityLabel("Warning: discarding will delete this workout session permanently")
        }
        .onAppear {
            viewModel.modelContext           = modelContext
            viewModel.purchaseManager        = purchaseManager
            viewModel.healthKitManager       = healthKitManager
            viewModel.authenticationManager  = authenticationManager
            viewModel.errorManager           = errorManager
            viewModel.dismissAction          = { dismiss() }
            viewModel.onAppear()
            isExerciseFocused = true
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    hrPulse = true
                }
            }
        }
        .onDisappear { viewModel.onDisappear() }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Zone-coloured radial glow — dims when paused
            RadialGradient(
                colors: [
                    zoneColor.opacity(viewModel.isPaused ? 0.06 : 0.22),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.35),
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: viewModel.dominantZone)
            .animation(.easeInOut(duration: 0.4), value: viewModel.isPaused)
        }
    }

    // MARK: - Workout Header

    private var workoutHeader: some View {
        HStack(spacing: 8) {
            if let symbol = workout.category?.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(themeColor)
            }
            Text(workout.title.uppercased())
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(themeColor)
                .tracking(2)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout: \(workout.title)")
    }

    // MARK: - Current Exercise

    @ViewBuilder
    private var exerciseSection: some View {
        if !workout.sortedExercises.isEmpty {
            VStack(spacing: 6) {
                // Exercise index pill
                let total = workout.effectiveExercises.count
                let index = min(viewModel.currentExerciseIndex, total - 1)
                Text("\(index + 1) of \(total)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)

                Text(workout.effectiveExercises[safe: index]?.name ?? "")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .accessibilityFocused($isExerciseFocused)
                    .accessibilityLabel("Current exercise: \(viewModel.currentExerciseText)")
            }
        }
    }

    // MARK: - Hero Timer

    private var timerSection: some View {
        VStack(spacing: 4) {
            Text(viewModel.formattedTime)
                .font(.system(size: 76, weight: .bold, design: .monospaced))
                .foregroundStyle(timerColor)
                .contentTransition(.numericText())
                .shadow(color: timerColor.opacity(viewModel.isPaused ? 0 : 0.45), radius: 18, y: 4)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isPaused)
                .accessibilityLabel("Elapsed time")
                .accessibilityValue(viewModel.formattedTime)

            Text("ELAPSED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(2)
        }
    }

    // MARK: - Round Progress

    @ViewBuilder
    private var roundProgressSection: some View {
        if workout.roundsEnabled && workout.roundsQuantity > 1 {
            VStack(spacing: 8) {
                Text("ROUND \(viewModel.currentRound) OF \(workout.roundsQuantity)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(2)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 4)
                        Capsule()
                            .fill(zoneColor)
                            .frame(
                                width: geo.size.width * min(
                                    Double(viewModel.currentRound) / Double(workout.roundsQuantity), 1.0
                                ),
                                height: 4
                            )
                            .animation(.easeInOut(duration: 0.4), value: viewModel.currentRound)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Round \(viewModel.currentRound) of \(workout.roundsQuantity)")
        }
    }

    // MARK: - Live Heart Rate (Premium)

    @ViewBuilder
    private var liveHeartRateSection: some View {
        if purchaseManager.isSubscribed && viewModel.currentHeartRate > 0 {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
                    .scaleEffect(hrPulse ? 1.2 : 1.0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: hrPulse
                    )
                Text("\(Int(viewModel.currentHeartRate)) BPM")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.top, 8)
            .accessibilityLabel("Live heart rate: \(Int(viewModel.currentHeartRate)) beats per minute")
        }
    }

    // MARK: - Post-Workout Metrics (Premium, watch-complication style)

    @ViewBuilder
    private var postWorkoutMetrics: some View {
        if purchaseManager.isSubscribed && viewModel.showMetrics {
            HStack(spacing: 10) {
                if let intensity = viewModel.intensityScore {
                    MetricChip(
                        icon: "flame.fill",
                        label: "INTENSITY",
                        value: "\(Int(intensity))%",
                        color: .orange
                    )
                }
                if let pulse = viewModel.progressPulseScore {
                    MetricChip(
                        icon: "heart.text.clipboard",
                        label: "PULSE",
                        value: "\(Int(pulse))",
                        color: themeColor
                    )
                }
                if let zone = viewModel.dominantZone {
                    MetricChip(
                        icon: "waveform.path.ecg",
                        label: "ZONE",
                        value: "Z\(zone)",
                        color: zoneColor
                    )
                }
            }
            .padding(.bottom, 16)
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Paused Banner

    @ViewBuilder
    private var pausedBanner: some View {
        if viewModel.isPaused {
            HStack(spacing: 6) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("PAUSED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 16)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel("Workout is paused")
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        VStack(spacing: 14) {
            // Primary: Next Exercise / Complete
            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                Task { await viewModel.primaryButtonAction() }
            } label: {
                ZStack {
                    if viewModel.isCompleting {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text(viewModel.primaryButtonText)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                            if viewModel.primaryButtonText == "Next Exercise" {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(themeColor)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: themeColor.opacity(0.4), radius: 12, y: 4)
            }
            .disabled(viewModel.isCompleting)
            .accessibilityLabel(viewModel.primaryButtonText)
            .accessibilityHint(viewModel.primaryButtonAccessibilityHint)
            .accessibilityIdentifier(viewModel.primaryButtonAccessibilityID)

            // Secondary: Pause / Resume
            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                viewModel.togglePause()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(viewModel.isCompleting)
            .accessibilityLabel(viewModel.isPaused ? "Resume workout" : "Pause workout")
        }
    }

    // MARK: - Hint Footer

    private var hintFooter: some View {
        VStack(spacing: 6) {
            if purchaseManager.isSubscribed {
                Text("Tap anywhere · \(Image(systemName: "digitalcrown.arrow.clockwise")) Crown advances exercise")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.25))
                    .multilineTextAlignment(.center)
            } else {
                Text("\(Image(systemName: "applewatch")) Use Digital Crown to advance exercises")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.25))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showDiscardAlert = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Cancel")
                        .font(.system(.subheadline, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - MetricChip (watch complication style)

private struct MetricChip: View {
    let icon:  String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
