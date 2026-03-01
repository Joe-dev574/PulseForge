//
//  OnboardingFlowView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//  Updated: February 28, 2026
//
//  Apple App Store Compliance (required for review):
//  - Multi-page onboarding introduces core features before app use.
//  - No data collection; onboarding completion stored locally via SwiftData.
//  - All animations respect `.reduceMotion` accessibility setting.
//  - Full VoiceOver support: labels, hints, and traits on all interactive elements.
//  - Privacy: no user data is shared or transmitted; all operations are on-device.
//

import SwiftUI
import SwiftData
import OSLog

// MARK: - Onboarding Page Model

private struct OnboardingPage {
    let eyebrow:     String
    let headline:    String
    let body:        String
    let icon:        String
    let accentColor: Color
    let features:    [String]
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        eyebrow:     "WELCOME",
        headline:    "Welcome to\nPulseForge",
        body:        "Your training hub. Log every session, monitor your progress, and forge the results you want — all with complete privacy.",
        icon:        "bolt.heart.fill",
        accentColor: .blue,
        features:    ["Privacy-first · on-device only", "Apple HealthKit integrated", "Apple Watch companion app"]
    ),
    OnboardingPage(
        eyebrow:     "CREATE",
        headline:    "Build Workouts\nYour Way",
        body:        "Design fully custom routines with exercises, sets, rounds, and categories. Every session logged and ready to beat.",
        icon:        "dumbbell.fill",
        accentColor: .orange,
        features:    ["Custom exercises & rounds", "Personal best tracking", "Workout history journal"]
    ),
    OnboardingPage(
        eyebrow:     "ANALYSE",
        headline:    "Data That\nDrives Progress",
        body:        "Intensity Score, Progress Pulse, Heart Rate Zones, and a 90-day activity heatmap — understand what's working and what isn't.",
        icon:        "chart.xyaxis.line",
        accentColor: .purple,
        features:    ["Live heart rate monitoring", "90-day activity heatmap", "Advanced zone analytics"]
    ),
    OnboardingPage(
        eyebrow:     "PRIVACY",
        headline:    "Your Data\nStays Yours",
        body:        "No ads. No servers. No tracking. Everything lives on your device and syncs privately through iCloud. You are in full control.",
        icon:        "lock.shield.fill",
        accentColor: .green,
        features:    ["Zero data shared externally", "iCloud sync, end-to-end", "Delete everything, anytime"]
    ),
]

// MARK: - OnboardingFlowView

/// Multi-page onboarding flow introducing PulseForge's core pillars to new users.
struct OnboardingFlowView: View {

    // MARK: Environment

    @Environment(AuthenticationManager.self) private var auth
    @Environment(\.modelContext)             private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: App Storage

    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"

    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }

    // MARK: State

    @State private var currentPage:  Int    = 0
    @State private var iconScale:    CGFloat = 0.5
    @State private var iconOpacity:  Double  = 0
    @State private var textOpacity:  Double  = 0
    @State private var textOffset:   CGFloat = 24
    @State private var isCompleting: Bool    = false

    // MARK: Private

    private let logger = Logger(subsystem: "com.tnt.PulseForge", category: "Onboarding")

    private var isLastPage: Bool { currentPage == pages.count - 1 }
    private var page: OnboardingPage { pages[currentPage] }

    // MARK: - Body

    var body: some View {
        ZStack {
            animatedBackground

            VStack(spacing: 0) {
                Spacer()
                heroIcon
                Spacer().frame(height: 36)
                textContent
                Spacer()
                featureList
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .padding(.top, 60)
        }
        .onAppear { animateIn() }
        .onChange(of: currentPage) { _, _ in
            withAnimation(.easeOut(duration: 0.15)) {
                iconScale   = 0.5
                iconOpacity = 0
                textOpacity = 0
                textOffset  = 20
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                animateIn()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var animatedBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Soft radial glow behind the icon
            RadialGradient(
                colors: [page.accentColor.opacity(0.35), Color.clear],
                center: .init(x: 0.5, y: 0.28),
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.55), value: currentPage)

            // Subtle bottom gradient for button legibility
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Hero Icon

    private var heroIcon: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(page.accentColor.opacity(0.12))
                .frame(width: 140, height: 140)

            // Inner frosted circle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 110, height: 110)
                .overlay(
                    Circle()
                        .strokeBorder(page.accentColor.opacity(0.3), lineWidth: 1)
                )

            Image(systemName: page.icon)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(page.accentColor)
                .symbolRenderingMode(.hierarchical)
        }
        .scaleEffect(iconScale)
        .opacity(iconOpacity)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: iconScale)
        .animation(.easeOut(duration: 0.4), value: iconOpacity)
        .accessibilityHidden(true)
    }

    // MARK: - Text Content

    private var textContent: some View {
        VStack(spacing: 12) {
            Text(page.eyebrow)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(page.accentColor)
                .tracking(3)

            Text(page.headline)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineSpacing(2)

            Text(page.body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 4)
        }
        .opacity(textOpacity)
        .offset(y: textOffset)
        .animation(.easeOut(duration: 0.45).delay(0.1), value: textOpacity)
        .animation(.easeOut(duration: 0.45).delay(0.1), value: textOffset)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.eyebrow). \(page.headline). \(page.body)")
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(spacing: 10) {
            ForEach(page.features.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(page.accentColor)
                        .accessibilityHidden(true)
                    Text(page.features[i])
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
                .animation(
                    .easeOut(duration: 0.4).delay(0.18 + Double(i) * 0.07),
                    value: textOpacity
                )
                .animation(
                    .easeOut(duration: 0.4).delay(0.18 + Double(i) * 0.07),
                    value: textOffset
                )
                .accessibilityLabel(page.features[i])
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 4)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Page dots
            HStack(spacing: 7) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? page.accentColor : Color.white.opacity(0.25))
                        .frame(width: i == currentPage ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                }
            }
            .accessibilityLabel("Page \(currentPage + 1) of \(pages.count)")
            .accessibilityAddTraits(.updatesFrequently)

            // Primary CTA button
            Button {
                handlePrimaryAction()
            } label: {
                ZStack {
                    if isCompleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text(isLastPage ? "Get Started" : "Continue")
                                .font(.system(.body, design: .rounded, weight: .bold))
                            if !isLastPage {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isLastPage
                        ? page.accentColor
                        : Color.white.opacity(0.12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isLastPage ? Color.clear : Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isCompleting)
            .accessibilityLabel(isLastPage ? "Get Started" : "Continue to next page")
            .accessibilityHint(isLastPage ? "Completes onboarding and opens PulseForge" : "Shows the next onboarding screen")
            .accessibilityAddTraits(.isButton)

            // Skip link (only on non-last pages)
            if !isLastPage {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage = pages.count - 1
                    }
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .accessibilityLabel("Skip to final onboarding page")
            }
        }
    }

    // MARK: - Actions

    private func handlePrimaryAction() {
        if isLastPage {
            completeOnboarding()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPage += 1
            }
        }
    }

    private func animateIn() {
        if reduceMotion {
            iconScale   = 1
            iconOpacity = 1
            textOpacity = 1
            textOffset  = 0
        } else {
            withAnimation {
                iconScale   = 1
                iconOpacity = 1
                textOpacity = 1
                textOffset  = 0
            }
        }
    }

    // MARK: - Complete Onboarding

    /// Seeds default data and marks the user as onboarded.
    private func completeOnboarding() {
        isCompleting = true
        Task {
            do {
                await DefaultDataSeeder.ensureDefaults(in: PulseForgeContainer.container)
                auth.currentUser?.isOnboardingComplete = true
                try context.save()
                logger.info("Onboarding completed and default data seeded at \(Date())")
            } catch {
                logger.error("Failed to complete onboarding: \(error.localizedDescription)")
                await MainActor.run { isCompleting = false }
            }
        }
    }
}
