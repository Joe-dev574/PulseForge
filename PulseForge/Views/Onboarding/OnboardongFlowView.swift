//
//  OnboardingFlowView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//  Updated: February 25, 2026
//

import SwiftUI
import SwiftData
import OSLog

/// The onboarding flow view for new users in **PulseForge**.
///
/// This view presents a welcoming introduction to the app's core features, emphasizing privacy,
/// simplicity, and HealthKit integration. It guides users through key benefits before completing
/// onboarding and seeding default data.
///
/// ## App Store Compliance
/// - Fully complies with Apple’s onboarding and accessibility guidelines.
/// - All elements include accessibility labels, hints, and traits for VoiceOver.
/// - Animations are subtle and automatically respect `.reduceMotion`.
/// - No data collection occurs here; onboarding completion is stored locally via SwiftData.
/// - Privacy: No user data is shared or transmitted; all operations are on-device.
///
/// - Note: Uses `@AppStorage` for theme color persistence.
struct OnboardingFlowView: View {
    
    // MARK: - Environment
    
    @Environment(AuthenticationManager.self) private var auth
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - App Storage
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    // MARK: - Computed Properties
    
    /// The current theme color with fallback to system blue.
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    // MARK: - Private Properties
    
    /// Logger for onboarding events and debugging.
    private let logger = Logger(subsystem: "com.tnt.PulseForge", category: "Onboarding")
    
    /// State to manage showing premium teaser (currently unused).
    @State private var showPremiumTeaser = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Enhanced adaptive gradient background
            LinearGradient(
                gradient: Gradient(colors: colorScheme == .dark
                                   ? [Color.black.opacity(0.5), Color.gray.opacity(0.3)]
                                   : [Color.white.opacity(0.9), Color.gray.opacity(0.15)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icons row with subtle pulse animation (respects Reduce Motion)
                HStack(spacing: 20) {
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(themeColor)
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(themeColor)
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    
                    Image(systemName: "applewatch")
                        .font(.system(size: 50))
                        .foregroundStyle(themeColor)
                        .shadow(color: .black.opacity(0.1), radius: 4)
                }
                .padding(.bottom, 24)
                .accessibilityHidden(true)
                .pulseEffect() // Custom subtle animation (defined below)
                
                // Welcome header
                VStack(spacing: 12) {
                    Text("Welcome to PulseForge")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Welcome to PulseForge")
                    
                    Text("Track workouts, journal progress, and stay consistent — all with complete privacy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .accessibilityLabel("Track workouts, journal progress, and stay consistent — all with complete privacy.")
                }
                
                // Feature highlights
                VStack(alignment: .leading, spacing: 16) {
                    FeatureItem(icon: "person.badge.key.fill", text: "Secure Apple ID login — your privacy first")
                    FeatureItem(icon: "heart.fill", text: "Seamless HealthKit integration for metrics")
                    FeatureItem(icon: "map.fill", text: "Auto-generated routes for runs, cycles, and rows")
                    FeatureItem(icon: "dumbbell.fill", text: "Custom workouts with rounds and exercises")
                    FeatureItem(icon: "chart.bar.fill", text: "Insightful analytics and trends")
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Get Started button
                Button {
                    completeOnboarding()
                    // showPremiumTeaser = true  // Uncomment when premium teaser is implemented
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .accessibilityLabel("Get Started")
                .accessibilityHint("Double-tap to complete onboarding and begin using PulseForge")
                .accessibilityAddTraits(.isButton)
            }
            .padding(.top, 60)
        }
    }
    
    // MARK: - Complete Onboarding
    
    /// Completes the onboarding process by seeding default data and marking the user as onboarded.
    ///
    /// This method is called when the user taps "Get Started".
    private func completeOnboarding() {
        Task {
            do {
                await DefaultDataSeeder.ensureDefaults(in: PulseForgeContainer.container)
                auth.currentUser?.isOnboardingComplete = true
                try context.save()
                logger.info("Onboarding completed and default data seeded at \(Date())")
            } catch {
                logger.error("Failed to complete onboarding: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Feature Item

/// A reusable view representing a single feature item in the onboarding list.
///
/// - Parameters:
///   - icon: SF Symbol name for the feature.
///   - text: Descriptive text for the feature.
struct FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Custom Animation Modifier

extension View {
    /// Applies a subtle pulse animation that automatically respects `.reduceMotion`.
    func pulseEffect() -> some View {
        self.modifier(PulseModifier())
    }
}

private struct PulseModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: UUID())
        }
    }
}
