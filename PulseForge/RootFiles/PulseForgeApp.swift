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
    
    /// Flag to skip the deduplication fetch on every launch once it has run cleanly.
    @AppStorage("hasDeduplicatedCategories") private var hasDeduplicatedCategories: Bool = false
    
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
                    // 1. Deduplicate only until confirmed clean once.
                    //    After that, skip the fetch on every launch.
                    if !hasDeduplicatedCategories {
                        deduplicateCategoriesIfNeeded()
                    }

                    // 2. Seed only when the store is genuinely empty
                    if !hasSeededDefaults {
                        await seedDefaultsIfNeeded()
                    }

                    // 3. Deferred: start PurchaseManager after the first frame
                    await PurchaseManager.shared.start()
                }
        }
    }
    
    /// Removes duplicate `Category` records from the SwiftData store.
    ///
    /// Duplicates can appear when:
    /// - The App Group store survives an app deletion (data persists)
    /// - CloudKit re-downloads the same categories from iCloud on reinstall
    /// - Both paths create distinct SwiftData records with identical names
    ///
    /// This runs synchronously on the main actor every launch, but is a
    /// no-op (one fetch, no deletions, no save) when the store is clean.
    @MainActor
    private func deduplicateCategoriesIfNeeded() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.categoryName, order: .forward)]
        )
        guard let all = try? context.fetch(descriptor), all.count > 0 else { return }

        var seen = Set<String>()
        var duplicatesRemoved = 0
        for category in all {
            if !seen.insert(category.categoryName).inserted {
                context.delete(category)
                duplicatesRemoved += 1
            }
        }

        if duplicatesRemoved > 0 {
            try? context.save()
            print("Removed \(duplicatesRemoved) duplicate category/categories.")
        } else {
            // Store is clean — skip this fetch on future launches.
            hasDeduplicatedCategories = true
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

