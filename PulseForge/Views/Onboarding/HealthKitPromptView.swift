//
//  HealthKitPromptView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/20/26.
//

import SwiftUI

/// A view that prompts the user to authorize HealthKit access, presented in a professional modal dialog style.
struct HealthKitPromptView: View {
    /// The selected theme color, stored in AppStorage.
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData:
        String = "#0096FF"
    /// Closure to execute when the user chooses to authorize HealthKit.
    var onAuthorize: () -> Void
    /// Closure to execute when the user dismisses the prompt.
    var onDismiss: () -> Void
    /// Computed theme color, derived from the stored hex string or defaulting to blue.
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    var body: some View {
        VStack(spacing: 20) {
            // Header with icon for visual appeal and context
            Image(systemName: "heart.text.square")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(themeColor)
                .accessibilityHidden(true)  // Decorative icon
            // Title for clear communication
            Text("Authorize HealthKit Access")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .accessibilityLabel("Authorize HealthKit Access title")
            // Detailed explanation of why authorization is needed
            Text(
                "PulseForge requires access to HealthKit to synchronize your workout and health data. This enables features such as automatic tracking, personalized fitness insights, and seamless integration with your health metrics."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .accessibilityLabel("HealthKit access explanation")
            // Authorize button with prominent styling
            Button("Authorize") {
                onAuthorize()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(themeColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("Authorize HealthKit button")
            .accessibilityHint("Tap to grant access to HealthKit")
            // Dismiss button with secondary styling
            Button("Dismiss") {
                onDismiss()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.2))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("Dismiss button")
            .accessibilityHint("Tap to close without authorizing")
        }
        .padding(10)
        .background(Color.proBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .frame(maxWidth: .infinity)  // Constrain width for better modal appearance on larger devices
    }
}
