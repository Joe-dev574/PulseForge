//
//  User.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftData

/// A SwiftData model representing a user's onboarding status and essential profile details.
///
/// Focuses on privacy: stores Apple ID, onboarding status, and optional identity details.
/// This model serves as the core user entity, linked to HealthMetrics for modularity.
/// - Important: Complies with Apple's privacy guidelines:
///   - Only stores minimal data: Apple User ID (required for Sign in with Apple) and optional name/email captured once.
///   - No server storage; all data is local and synced via private iCloud (end-to-end encrypted).
///   - For App Review: Demonstrate Sign in with Apple integration, data handling, and no unauthorized sharing.
/// - Privacy: Contains potentially identifying info (e.g., email); ensure user consent and minimal collection.
/// - Note: Use with AuthenticationManager for session management.
@Model
final class User {
    // MARK: - Properties
    /// Unique identifier from Sign in with Apple (mandatory for authentication).
    var appleUserId: String = ""  // Unique identifier from Sign in with Apple (mandatory)
    
    /// Tracks if onboarding (permissions, setup) is done.
    var isOnboardingComplete: Bool = false  // Tracks if onboarding (permissions, setup) is done
    
    // Optional identity/profile details
    /// User's email address (optional; captured during initial Sign in with Apple if provided).
    var email: String?
    
    /// User's display name (optional; derived from full name during initial Sign in with Apple).
    var displayName: String?
    
    // Relationship to health metrics (one-to-one)
    /// Linked HealthMetrics for user-specific health data (optional inverse relationship).
    /// - Note: Uses default delete rule; HealthMetrics can persist independently if needed.
    var healthMetrics: HealthMetrics?
    
    // MARK: - Initialization
    /// Designated initializer that ensures all stored properties are initialized.
    /// - Parameters:
    ///   - appleUserId: The Apple User ID (required).
    ///   - email: Optional email address.
    ///   - isOnboardingComplete: Onboarding status (defaults to false).
    ///   - displayName: Optional display name.
    /// - Important: Validates that appleUserId is not empty to ensure data integrity.
    init(
        appleUserId: String,
        email: String? = nil,
        isOnboardingComplete: Bool = false,
        displayName: String? = nil
    ) {
        precondition(!appleUserId.isEmpty, "Apple User ID must not be empty")
        self.appleUserId = appleUserId
        self.email = email
        self.isOnboardingComplete = isOnboardingComplete
        self.displayName = displayName
    }
}

