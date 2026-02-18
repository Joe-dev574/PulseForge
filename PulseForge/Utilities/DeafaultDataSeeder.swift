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
    
    /// Ensures default categories are seeded in the provided container.
    /// - Parameter container: The ModelContainer to use for seeding.
    public static func ensureDefaults(in container: ModelContainer) async {
        let context = ModelContext(container)
        
        // Check if categories already exist
        let descriptor = FetchDescriptor<Category>()
        do {
            let existingCount = try context.fetchCount(descriptor)
            if existingCount > 0 {
                logger.debug("Categories already exist; skipping seeding.")
                return
            }
        } catch {
            logger.error("Failed to check existing categories: \(error.localizedDescription)")
            return
        }
        
        // Seed default categories with proper color rawValues matching asset catalog
        let defaults: [(name: String, symbol: String, color: CategoryColor)] = [
            ("Cardio", "heart.fill", .CARDIO),
            ("Cross Train", "figure.cross.training", .CROSSTRAIN),
            ("Cycling", "figure.outdoor.cycle", .CYCLING),
            ("Grappling", "figure.wrestling", .GRAPPLING),
            ("HIIT", "flame.fill", .HIIT),
            ("Hiking", "figure.hiking", .HIKING),
            ("Jump Rope", "figure.jumprope", .JUMPROPE),
            ("Pilates", "figure.pilates", .PILATES),
            ("Power", "dumbbell.fill", .POWER),
            ("Recovery", "figure.cooldown", .RECOVERY),
            ("Rowing", "figure.rower", .ROWING),
            ("Run", "figure.run", .RUN),
            ("Stretch", "figure.flexibility", .STRETCH),
            ("Strength", "figure.strengthtraining.traditional", .STRENGTH),
            ("Swimming", "figure.pool.swim", .SWIMMING),
            ("Test", "figure.mixed.cardio", .TEST),
            ("Walk", "figure.walk", .WALK),
            ("Yoga", "figure.yoga", .YOGA)
        ]
        
        for (name, symbol, color) in defaults {
            let category = Category(categoryName: name, symbol: symbol, categoryColor: color)
            context.insert(category)
        }
        
        do {
            try context.save()
            logger.info("Default categories seeded successfully.")
        } catch {
            logger.error("Failed to seed default categories: \(error.localizedDescription)")
        }
    }
}



