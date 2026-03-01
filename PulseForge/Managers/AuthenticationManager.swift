//
//  AuthenticationManager.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import AuthenticationServices
import OSLog
import SwiftUI
import SwiftData
import Observation

/// Central manager for Sign in with Apple authentication.
///
/// Handles session lifecycle, persistent user storage via SwiftData,
/// and shared App Group state for cross-target restoration (e.g., Watch).
///
/// Security & Privacy:
/// - Stores only Apple User ID persistently (non-secret identifier)
/// - Captures name/email only once during initial authorization
/// - Local-only storage; no server transmission
/// - Complies with minimal scopes and revocation handling
///
/// Usage: Access via `AuthenticationManager.shared` or inject via @Environment

@MainActor
@Observable
final class AuthenticationManager {
    // MARK: - Public Observable State
    /// The currently authenticated user, if signed in.
    var currentUser: User?
    
    /// Indicates whether a user is currently signed in.
    var isSignedIn: Bool { currentUser != nil }
    
    // MARK: - Constants
    /// Identifier for the shared App Group used for cross-process data sharing.
    private let appGroupIdentifier = "group.com.tnt.PulseForge"
    
    /// Key for storing the Apple User ID in shared defaults.
    private let appleUserIDKey = "appleUserID"
    
    // MARK: - Dependencies
    /// The SwiftData model container for User persistence.
    private let modelContainer: ModelContainer
    
    /// Logger for authentication-related events.
    private let logger = Logger(
        subsystem: "com.tnt.PulseForge",
        category: "Auth"
    )
    
    // MARK: - Shared App Group Defaults
    /// Access to shared UserDefaults for App Group.
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // MARK: - Singleton
    /// Shared instance for app-wide access.
    ///
    /// Use this singleton to access authentication state from anywhere in the app.
    static let shared = AuthenticationManager(
        modelContainer: PulseForgeContainer.container
    )
    
    /// Initializes the manager with a model container and restores any existing session.
    private init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        restoreSession()
        observeCredentialRevocation()
    }
    
    // MARK: - Session Management
    /// Restores the user session from shared App Group defaults if available.
    ///
    /// This method is called during initialization to automatically sign in returning users.
    /// If a stale Apple User ID is found (no matching User in SwiftData), it is cleared.
    private func restoreSession() {
        guard let defaults = sharedDefaults else {
            logger.error("Unable to access shared App Group defaults")
            return
        }
        
        guard let appleUserId = defaults.string(forKey: appleUserIDKey) else {
            logger.debug("No Apple User ID in shared defaults – user not signed in")
            return
        }
        
        if let user = fetchUser(appleUserId: appleUserId) {
            currentUser = user
            logger.info("Session restored from shared defaults for user: \(appleUserId.prefix(8))...")
        } else {
            logger.warning("Apple User ID found in defaults but no matching User – clearing stale ID")
            defaults.removeObject(forKey: appleUserIDKey)
        }
    }
    // MARK: - Revocation Handling
        private func observeCredentialRevocation() {
            NotificationCenter.default.addObserver(
                forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.signOut()
                    self.logger.critical("Apple credential revoked – user signed out")
                    // Optional: Post in-app notification or show alert in root view
                }
            }
        }
    /// Completes the sign-in process by setting the current user and persisting the session.
    ///
    /// New users are left with `isOnboardingComplete == false` so that `ContentView`
    /// routes them through `OnboardingFlowView` naturally.
    /// `OnboardingFlowView` is responsible for setting `isOnboardingComplete = true`
    /// when the user finishes the flow.
    ///
    /// - Parameter user: The User object to sign in.
    func completeSignIn(with user: User) {
        self.currentUser = user

        // Persist Apple User ID to shared App Group for session restoration.
        sharedDefaults?.set(user.appleUserId, forKey: appleUserIDKey)
        logger.info("Apple User ID saved to shared defaults")

        // NOTE: Do NOT set isOnboardingComplete = true here.
        // New users have isOnboardingComplete = false (the model default).
        // ContentView will route them to OnboardingFlowView, which sets the
        // flag to true on completion. Auto-completing it here bypassed onboarding entirely.
        logger.debug("Sign-in complete for user \(user.appleUserId.prefix(8))… — onboarding state: \(user.isOnboardingComplete)")
    }
    
    /// Signs out the current user and clears session data.
    func signOut() {
        sharedDefaults?.removeObject(forKey: appleUserIDKey)
        currentUser = nil
        logger.info("User signed out – cleared shared defaults")
    }
    
    // MARK: - Sign in with Apple Handlers
    /// Configures the Sign in with Apple authorization request.
    ///
    /// - Parameter request: The ASAuthorizationAppleIDRequest to configure.
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        logger.debug("Configured Sign in with Apple request with scopes")
    }
    
    /// Handles the completion of a Sign in with Apple authorization.
    ///
    /// Fetches an existing user or creates a new one, capturing optional name/email on first sign-in.
    ///
    /// - Parameter credential: The ASAuthorizationAppleIDCredential from the authorization.
    func handleAuthorizationCompletion(_ credential: ASAuthorizationAppleIDCredential) {
        let appleUserId = credential.user
        
        logger.info("Received Apple ID: \(appleUserId.prefix(8))...")
        
        // Fetch existing user or create new one
        if let existingUser = fetchUser(appleUserId: appleUserId) {
            completeSignIn(with: existingUser)
        } else {
            let newUser = createNewUser(appleUserId: appleUserId)
            // Capture name/email if provided (only on first sign-in per Apple guidelines)
            if let fullName = credential.fullName,
               let givenName = fullName.givenName,
               let familyName = fullName.familyName {
                newUser.displayName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
            }
            if let email = credential.email {
                newUser.email = email
            }
            completeSignIn(with: newUser)
        }
    }
    
    // MARK: - Simulator Support
    /// Bypasses Sign in with Apple for simulator testing by creating a debug user.
    ///
    /// This is idempotent and only active in simulator environments.
    /// Safe for production builds as it returns early in non-simulator targets.
    func bypassSignInForSimulator() {
        guard isSimulator else { return }
        
        let debugAppleUserID = "simulator.debug.user.12345"
        
        // Save to shared defaults
        sharedDefaults?.set(debugAppleUserID, forKey: appleUserIDKey)
        
        // Fetch or create debug user
        if let existingUser = fetchUser(appleUserId: debugAppleUserID) {
            existingUser.isOnboardingComplete = true
            let context = ModelContext(modelContainer)
            do {
                try context.save()
                self.currentUser = existingUser
                logger.info("Simulator bypass: existing debug user signed in")
            } catch {
                logger.error("Simulator bypass failed to save: \(error.localizedDescription)")
            }
            return
        }
        
        // Create new debug user
        let context = ModelContext(modelContainer)
        let debugUser = User(
            appleUserId: debugAppleUserID,
            isOnboardingComplete: true
        )
        context.insert(debugUser)
        
        do {
            try context.save()
            self.currentUser = debugUser
            logger.info("Simulator bypass: new debug user created and signed in")
        } catch {
            logger.error("Simulator bypass failed to save debug user: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    /// Creates and saves a new User in SwiftData.
    ///
    /// - Parameter appleUserId: The Apple User ID for the new user.
    /// - Returns: The newly created User.
    private func createNewUser(appleUserId: String) -> User {
        let context = ModelContext(modelContainer)
        let newUser = User(appleUserId: appleUserId)
        context.insert(newUser)
        
        do {
            try context.save()
            logger.info("New User created and saved")
        } catch {
            logger.error("Failed to save new User: \(error.localizedDescription)")
            // Optimization: In production, add retry or error propagation
        }
        
        return newUser
    }
    
    /// Fetches a User from SwiftData by Apple User ID.
    ///
    /// - Parameter appleUserId: The Apple User ID to query.
    /// - Returns: The matching User, or nil if not found.
    private func fetchUser(appleUserId: String) -> User? {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { $0.appleUserId == appleUserId }
        )
        
        do {
            if let user = try context.fetch(descriptor).first {
                logger.debug("User fetched successfully from SwiftData")
                return user
            } else {
                logger.debug("No User found in SwiftData for Apple User ID: \(appleUserId.prefix(8))...")
                return nil
            }
        } catch {
            logger.error("Failed to fetch User from SwiftData: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Simulator Detection
extension AuthenticationManager {
    /// Detects if the code is running in a simulator environment.
    var isSimulator: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }
}


