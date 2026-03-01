//
//  DeafaultDataSeeder.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftData
import OSLog

@MainActor
public final class DefaultDataSeeder {
    private static let logger = Logger(subsystem: "com.tnt.PulseForge", category: "DefaultDataSeeder")
    
    /// Ensures default categories are present in the provided container.
    ///
    /// Unlike a simple "skip if any categories exist" guard, this function
    /// checks **each category by name** before inserting it. This makes the
    /// seeder safe to call multiple times (e.g. from onboarding completion)
    /// and resilient to CloudKit merging extra records into the store.
    ///
    /// - Parameter container: The ModelContainer to use for seeding.
    public static func ensureDefaults(in container: ModelContainer) async {
        let context = ModelContext(container)

        let defaults: [(name: String, symbol: String, color: CategoryColor)] = [
            ("Cardio",       "heart.fill",                          .CARDIO),
            ("Cross Train",  "figure.cross.training",               .CROSSTRAIN),
            ("Cycling",      "figure.outdoor.cycle",                .CYCLING),
            ("Grappling",    "figure.wrestling",                    .GRAPPLING),
            ("HIIT",         "flame.fill",                          .HIIT),
            ("Hiking",       "figure.hiking",                       .HIKING),
            ("Jump Rope",    "figure.jumprope",                     .JUMPROPE),
            ("Pilates",      "figure.pilates",                      .PILATES),
            ("Power",        "dumbbell.fill",                       .POWER),
            ("Recovery",     "figure.cooldown",                     .RECOVERY),
            ("Rowing",       "figure.rower",                        .ROWING),
            ("Run",          "figure.run",                          .RUN),
            ("Stretch",      "figure.flexibility",                  .STRETCH),
            ("Strength",     "figure.strengthtraining.traditional", .STRENGTH),
            ("Swimming",     "figure.pool.swim",                    .SWIMMING),
            ("Test",         "figure.mixed.cardio",                 .TEST),
            ("Walk",         "figure.walk",                         .WALK),
            ("Yoga",         "figure.yoga",                         .YOGA),
        ]

        // Single fetch: grab all existing category names in one query instead of 18.
        let allDescriptor = FetchDescriptor<Category>()
        let existingNames: Set<String>
        if let existing = try? context.fetch(allDescriptor) {
            existingNames = Set(existing.map(\.categoryName))
        } else {
            existingNames = []
        }

        var insertedCount = 0

        for (name, symbol, color) in defaults where !existingNames.contains(name) {
            context.insert(Category(categoryName: name, symbol: symbol, categoryColor: color))
            insertedCount += 1
        }

        guard insertedCount > 0 else {
            logger.debug("All default categories already present; nothing inserted.")
            return
        }

        do {
            try context.save()
            logger.info("Seeded \(insertedCount) default category/categories.")
        } catch {
            logger.error("Failed to save seeded categories: \(error.localizedDescription)")
        }
    }
}



