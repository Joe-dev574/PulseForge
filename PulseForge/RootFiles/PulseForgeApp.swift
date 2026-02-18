//
//  PulseForgeApp.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI
import SwiftData

/// The main entry point for the NorthTrax iOS app.
///
/// Configures the app scene, injects shared dependencies, applies user preferences,
/// and safely seeds default data on first launch using the main actor.

@main
struct PulseForgeApp: App {
    /// User's preferred appearance (system, light, dark), persisted across launches.
    @AppStorage("appearanceSetting") private var appearanceSetting: AppearanceSetting = .system
    
    /// Flag to track if default data has been seeded (prevents repeated seeding).
    @AppStorage("hasSeededDefaults") private var hasSeededDefaults: Bool = false
    
    /// Shared app-wide SwiftData container.
    private let container: ModelContainer = PulseForgeContainer.container
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(HealthKitManager.shared)
                .environment(PurchaseManager.shared)
                .environment(ErrorManager.shared)
                .environment(AuthenticationManager.shared)
                .environment(MetricsManager.shared)
                .modelContainer(container)
                .preferredColorScheme(appearanceSetting.colorScheme)
                .task {
                    // Run seeding only once, on main actor
                    if !hasSeededDefaults {
                        await seedDefaultsIfNeeded()
                    }
                }
        }
    }
    
    /// Seeds default categories and other initial data exactly once.
    /// Runs on the main actor to ensure safe interaction with the shared container's main context.
    @MainActor
    private func seedDefaultsIfNeeded() async {
        let context = container.mainContext  // Always use the container's main context
        
        // Quick check: if categories already exist, skip (redundant but fast)
        let fetchRequest = FetchDescriptor<Category>()
        guard let count = try? context.fetchCount(fetchRequest), count == 0 else {
            print("Categories already exist; skipping seeding.")
            hasSeededDefaults = true
            return
        }
        
        await DefaultDataSeeder.ensureDefaults(in: container)
        // Only mark as seeded after successful insertion + implicit save
        hasSeededDefaults = true
        do {
            try context.save()  // Explicit save for safety (though SwiftData auto-saves)
            print("Default data seeded successfully.")
        } catch {
            print("Failed to save context after seeding: \(error.localizedDescription)")
        }
    }
}

