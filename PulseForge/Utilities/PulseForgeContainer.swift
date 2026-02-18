//
//  PulseForgeContainer.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftData
import CloudKit
import Foundation

/// Provides a shared ModelContainer for SwiftData, configured with App Group storage and optional CloudKit synchronization.
///
/// This class initializes a singleton ModelContainer that supports shared data access across the app and its extensions (e.g., Apple Watch).
/// For premium users, it enables private CloudKit database synchronization for end-to-end encrypted iCloud backups and cross-device sync.
///
/// - Note: The container uses an App Group for file storage to enable data sharing with the Watch app.
/// - Important: Ensure the App Group ("group.com.tnt.NorthTrax") and CloudKit container ("iCloud.com.tnt.NorthTrax") are configured in the project entitlements and capabilities.
/// - Warning: The schema includes all persistent models. View models (e.g., WorkoutSessionViewModel) should not be included here as they are not @Model entities.
/// - Privacy: When CloudKit is enabled (premium only), data syncs privately via end-to-end encryption. No server-side access; complies with Apple's privacy guidelines for HealthKit-adjacent data.
public final class PulseForgeContainer {
    /// The shared ModelContainer instance, lazily initialized with the app's schema and configuration.
    public static let container: ModelContainer = {
        // Retrieve premium status from shared UserDefaults
        let appGroupDefaults = UserDefaults(suiteName: "") ?? .standard
        let isPremium = appGroupDefaults.bool(forKey: "isPremium")
        
        // Define the schema with all @Model entities
        let schema = Schema([
            User.self,
            HealthMetrics.self,
            Category.self,
            Workout.self,
            SplitTime.self,
            History.self,
            Exercise.self
        ])
        
        let fileManager = FileManager.default
        guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.tnt.PulseForge") else {
            fatalError("Failed to get App Group container URL. Ensure App Groups are configured in project capabilities.")
        }
        
        // Ensure the App Group directory exists
        do {
            try fileManager.createDirectory(at: groupURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatalError("Failed to create App Group directory: \(error.localizedDescription)")
        }
        
        let storeURL = groupURL.appendingPathComponent("PulseForge.store")
        
        // Configure CloudKit based on premium status
        let modelConfiguration: ModelConfiguration
        if isPremium {
            modelConfiguration = ModelConfiguration(
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .private("iCloud.com.tnt.PulseForge")
            )
        } else {
            modelConfiguration = ModelConfiguration(
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none // No sync for non-premium; data local to device
            )
        }
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription). Check schema compatibility and entitlements.")
        }
    }()
    
    private init() {}
}
