//
//  AuthenticationView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//  Updated: February 25, 2026
//

import SwiftUI
import AuthenticationServices
import OSLog

/// The authentication view for signing in with Apple ID in **PulseForge**.
///
/// This view presents a clean, privacy-focused sign-in screen using Sign in with Apple.
/// It handles the full authorization flow and presents errors appropriately.
///
/// ## App Store Compliance
/// - Requests only minimal scopes (`.fullName`, `.email`).
/// - Stores only the Apple User ID persistently; name and email are captured once if provided.
/// - All data remains on-device or in private iCloud (end-to-end encrypted).
/// - Includes a valid link to the app’s Privacy Policy (required for review).
/// - Full accessibility support for VoiceOver.
///
/// - Important: This view complies with Apple’s Human Interface Guidelines and Sign in with Apple requirements.
/// - Privacy: No data is transmitted to third-party servers. Authentication is handled entirely by Apple on-device.
struct AuthenticationView: View {
    
    // MARK: - Environment
    
    @Environment(AuthenticationManager.self) private var auth
    @Environment(ErrorManager.self) private var errorManager
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - App Storage
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    // MARK: - Computed Properties
    
    /// The current theme color with fallback to system blue.
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    // MARK: - Constants
    
    private let privacyPolicyURL = URL(string: "https://pulseforge.app/privacy")!
    private let supportEmailURL = URL(string: "mailto:support@pulseforge.app")!
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Adaptive background gradient
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
                
                // App icon (decorative)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 80))
                    .foregroundStyle(themeColor)
                    .accessibilityHidden(true)
                
                // Welcome text
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
                
                Spacer()
                
                // Sign in with Apple button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        auth.handleSignInWithAppleRequest(request)
                    },
                    onCompletion: { result in
                        Task {
                            await handleSignInResult(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .padding(.horizontal, 40)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Sign in with Apple")
                .accessibilityHint("Double-tap to sign in using your Apple ID")
                .accessibilityAddTraits(.isButton)
                
                // Privacy & Terms link (required for App Review)
                Button {
                    UIApplication.shared.open(privacyPolicyURL)
                } label: {
                    Text("Terms and Privacy Policy")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .accessibilityLabel("Terms and Privacy Policy")
                .accessibilityHint("Double-tap to view PulseForge privacy policy and terms")
                .accessibilityAddTraits(.isLink)
            }
            .padding(.vertical, 40)
            .animation(.easeInOut(duration: 0.5), value: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("PulseForge sign-in screen")
        }
    }
    
    // MARK: - Sign-In Result Handler
    
    /// Handles the result of the Sign in with Apple authorization.
    ///
    /// - Parameter result: The authorization result from Apple.
    ///
    /// - Note:
    ///   - User cancellations are ignored silently (per Apple guidelines).
    ///   - All other errors are presented to the user via `ErrorManager`.
    ///   - Success is passed to `AuthenticationManager` for user creation or restoration.
    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                auth.handleAuthorizationCompletion(credential)
            } else {
                errorManager.present(
                    title: "Sign-In Error",
                    message: "Received unexpected credential type from Apple."
                )
            }
            
        case .failure(let error):
            // User cancelled – no alert needed (Apple guideline)
            if (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            
            errorManager.present(
                title: "Sign-In Failed",
                message: error.localizedDescription
            )
        }
    }
}
