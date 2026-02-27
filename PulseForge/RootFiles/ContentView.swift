//
//  ContentView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//  Updated: February 25, 2026
//
//  Apple App Store Compliance:
//  - Manages top-level navigation flow based on authentication and onboarding state.
//  - No sensitive data is processed here — all authentication is handled by AuthenticationManager.
//  - Brief loading state shown while restoring session (required for smooth UX).
//  - Full accessibility support with clear labels and hints.
//  - Complies with App Review Guidelines 3.3.2 (Accessibility) and 5.1.1 (Data Handling).
//

import SwiftUI
import SwiftData
import OSLog

/// The root view of PulseForge.
///
/// This view controls the initial navigation flow:
/// - Loading → Authentication → Onboarding → Main App (WorkoutListScreen)
///
/// It waits for `AuthenticationManager` to restore the user session before showing content.
struct ContentView: View {
    
    // MARK: - Environment
    
    @Environment(AuthenticationManager.self) private var auth
    
    // MARK: - State
    
    /// Shows a loading indicator while the authentication state is being restored.
    @State private var isLoading = true
    
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.pulseforge.PulseForge", category: "ContentView")
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if !auth.isSignedIn {
                    AuthenticationView()
                } else if auth.currentUser?.isOnboardingComplete != true {
                    OnboardingFlowView()
                } else {
                    WorkoutListScreen()
                }
            }
        }
        .task {
            await restoreAuthenticationState()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .tint(.blue)
            
            Text("Initializing PulseForge...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.proBackground)
        .accessibilityLabel("PulseForge is loading")
        .accessibilityHint("Please wait while we restore your session")
    }
    
    // MARK: - Private Methods
    
    /// Restores the authentication state and transitions away from the loading screen.
    ///
    /// This runs once when ContentView appears and ensures a smooth, non-flashing transition.
    private func restoreAuthenticationState() async {
        logger.info("ContentView appeared — Checking authentication state")
        
        // Give AuthenticationManager a moment to restore from shared defaults / SwiftData
        // (Usually completes instantly, but we add a tiny safety delay for first launch)
        try? await Task.sleep(for: .milliseconds(400))
        
        logger.info("""
            Authentication check complete → 
            Signed in: \(auth.isSignedIn) | 
            Onboarding complete: \(auth.currentUser?.isOnboardingComplete ?? false)
            """)
        
        // Smooth transition away from loading screen
        withAnimation(.easeInOut(duration: 0.25)) {
            isLoading = false
        }
    }
}
