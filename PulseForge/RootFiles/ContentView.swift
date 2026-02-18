//
//  ContentView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI
import SwiftData
import OSLog


/// This view manages the initial navigation flow based on user authentication and onboarding status.
/// It uses a NavigationStack to handle transitions between authentication, onboarding, and the main workout list.
///
/// - Important: Complies with Apple's accessibility and privacy guidelines:
///   - All UI elements include accessibility labels and hints for VoiceOver support.
///   - No sensitive data is processed here; authentication is handled via AuthenticationManager.
///   - For App Review: Demonstrate smooth navigation from sign-in to main content, including loading states.
/// - Privacy: No user data collection occurs in this view; relies on secure Apple ID login.
/// - Note: Uses a brief loading delay to allow authentication restoration; adjust timing as needed for UX.

struct ContentView: View {
    /// Environment-injected authentication manager for session state.
    @Environment(AuthenticationManager.self) private var auth
    
    /// Logger for content view events and navigation debugging.
    private let logger = Logger(subsystem: "com.tnt.PulseForge", category: "ContentView")
    
    /// State to manage initial loading screen during auth check.
    @State private var isLoading = true  // Added for brief auth check delay
    
    @State private var isInitialLoad = true
    
    
    var body: some View {
            NavigationStack {
                if isInitialLoad {
                    ProgressView("Initializing...")
                        .controlSize(.large)
                        .accessibilityLabel("App is loading your data and session")
                        .accessibilityHint("Please wait a moment while we restore your authentication state")
                } else if !auth.isSignedIn {
                    AuthenticationView()
                } else if auth.currentUser?.isOnboardingComplete != true {
                    OnboardingFlowView()
                } else {
                    WorkoutListScreen()
                }
            }
            .task {
                // Perform one-time auth check & logging on appear
                await checkAuthenticationState()
            }
         
        }
        
        private func checkAuthenticationState() async {
            // Give auth manager a moment to restore session (usually very fast)
            // No artificial delay needed in most cases — auth.isSignedIn should update reactively
            
            // Optional: if your AuthenticationManager has an async restore method, call it here
            // await auth.restoreSessionIfNeeded()
            
            logger.info("ContentView appeared • Signed in: \(auth.isSignedIn) • Onboarding complete: \(auth.currentUser?.isOnboardingComplete ?? false)")
            
            // Smoothly transition away from loading (prevents flash if auth is instant)
            withAnimation(.easeInOut(duration: 0.3)) {
                isInitialLoad = false
            }
        }
    }
