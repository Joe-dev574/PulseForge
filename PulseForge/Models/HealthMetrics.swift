//
//  HealthMetrics.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import OSLog

/// Represents a single progress selfie taken by the user.
///
/// This struct stores image data and metadata for user progress photos, used in the app's metrics tab for visual tracking.
/// - Important: Image data is stored as Data for persistence; ensure compliance with Apple's storage guidelines by optimizing image sizes before saving.
/// - Privacy: Selfies contain personal images; data is stored locally and synced via private iCloud (end-to-end encrypted). No server transmission.
/// - Note: Conforms to Identifiable for UI lists, Codable for potential export/import, and Hashable for set operations if needed.
struct ProgressSelfie: Identifiable, Codable, Hashable {
    /// Unique identifier for the selfie, generated as a UUID.
    let id: UUID
    
    /// Raw image data (e.g., from UIImage.jpegData or PNG).
    var imageData: Data
    
    /// Date when the selfie was added or taken.
    var dateAdded: Date
    
    /// Formatted display name for the selfie, e.g., "May '25".
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: dateAdded)
    }
    
    /// Initializes a progress selfie with image data and date.
    /// - Parameters:
    ///   - id: Unique ID (defaults to a new UUID).
    ///   - imageData: The image data to store.
    ///   - dateAdded: The date the selfie was added (defaults to now).
    init(id: UUID = UUID(), imageData: Data, dateAdded: Date = Date()) {
        self.id = id
        self.imageData = imageData
        self.dateAdded = dateAdded
    }
}

/// A SwiftData model representing a user's health metrics and additional profile details.
///
/// This model is linked to the User model via a one-to-one relationship for modularity and privacy.
/// It supports the app's metrics tab by storing and syncing health data derived from HealthKit or manual entry.
///
/// - Important: Complies with Apple's HealthKit and privacy guidelines:
///   - All properties are optional to handle partial data availability.
///   - Data is processed on-device; sync via private iCloud only (end-to-end encrypted).
///   - For App Review: Demonstrate how data is sourced (e.g., HealthKit reads) and protected; no sharing without explicit consent.
///   - Integrate with HealthKitManager for automated fetches where possible.
/// - Privacy: Contains sensitive health info (e.g., weight, heart rate); ensure user consent and minimal collection.
/// - Note: Use @Attribute(.externalStorage) for large binary data like images to optimize database performance.
@Model
final class HealthMetrics {
    // MARK: - Properties
    // Health Metrics
    /// User's weight in kilograms (optional; from HealthKit or manual entry).
    var weight: Double?  // in kilograms
    
    /// User's height in meters (optional; from HealthKit or manual entry).
    var height: Double?  // in meters
    
    /// User's age in years (optional; calculated from date of birth via HealthKit).
    var age: Int?
    
    /// Resting heart rate in beats per minute (optional; from HealthKit).
    var restingHeartRate: Double?  // in beats per minute
    
    /// Maximum heart rate in beats per minute (optional; user-entered or estimated via formula).
    var maxHeartRate: Double?  // in beats per minute. Can be user-entered or estimated.
    
    /// String representation of biological sex (e.g., "Male", "Female", "Other", "Not Set"; from HealthKit).
    var biologicalSexString: String?  // Storing HKBiologicalSex.description or a custom string
    // Options: "Male", "Female", "Other", "Not Set"
    
    // Additional Profile Details
    /// User's fitness goal (e.g., "Weight Loss", "Muscle Gain"; defaults to "General Fitness").
    var fitnessGoal: String?
    
    /// Profile image data, stored externally for efficiency.
    @Attribute(.externalStorage) var profileImageData: Data?
    
    /// Array of progress selfies for visual tracking.
    var progressSelfies: [ProgressSelfie] = []
    
    // Relationship back to User (one-to-one)
    /// The associated User (optional inverse relationship).
    var user: User?
    
    // MARK: - Initialization
    /// Designated initializer that ensures all stored properties are initialized.
    /// - Parameters:
    ///   - weight: Optional weight in kg.
    ///   - height: Optional height in meters.
    ///   - age: Optional age in years.
    ///   - restingHeartRate: Optional resting HR in bpm.
    ///   - maxHeartRate: Optional max HR in bpm.
    ///   - biologicalSexString: Optional biological sex string.
    ///   - fitnessGoal: Optional fitness goal (defaults to "General Fitness").
    ///   - profileImageData: Optional profile image data.
    ///   - progressSelfies: Array of progress selfies (defaults to empty).
    init(
        weight: Double? = nil,
        height: Double? = nil,
        age: Int? = nil,
        restingHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        biologicalSexString: String? = nil,
        fitnessGoal: String? = "General Fitness",
        profileImageData: Data? = nil,
        progressSelfies: [ProgressSelfie] = []
    ) {
        self.weight = weight
        self.height = height
        self.age = age
        self.restingHeartRate = restingHeartRate
        self.maxHeartRate = maxHeartRate
        self.biologicalSexString = biologicalSexString
        self.fitnessGoal = fitnessGoal
        self.profileImageData = profileImageData
        self.progressSelfies = progressSelfies
    }
}
