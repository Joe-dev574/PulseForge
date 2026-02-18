//
//  Exercise.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftData
import Foundation

/// A persistent model representing an individual exercise within a workout.
///
/// This class stores exercise details, including name and order, and maintains relationships
/// with SplitTime entities for timing data. It conforms to SwiftData’s @Model for automatic
/// persistence and querying.
///
/// - Privacy: No user-identifiable data stored here; exercises are app-defined or user-created workout components.
/// - Note: The `id` is a UUID for unique identification across devices and sync scenarios.

@Model
final class Exercise {
    /// Unique identifier for the exercise, automatically generated as a UUID.
    var id: UUID = UUID()
    
    /// The name of the exercise (e.g., "Bench Press", "5K Run").
    var name: String = "New Exercise"
    
    /// The order of this exercise within its parent workout (0-based index).
    var order: Int = 0
    
    // CloudKit-safe to-many relationship with proper inverse
    /// Array of split times recorded for this exercise during workouts.
    /// - Note: Uses cascade delete to remove associated SplitTimes when the Exercise is deleted.
    @Relationship(deleteRule: .cascade)
    var splitTimes: [SplitTime]? = []
    
    // Optional: link back to parent workout (not required for now)
    /// The parent Workout this exercise belongs to (optional inverse relationship).
    var workout: Workout?
    
    /// Initializes a new exercise with the specified name and order.
    /// - Parameters:
    ///   - name: The name of the exercise (defaults to "New Exercise").
    ///   - order: The position in the workout sequence (defaults to 0).
    init(name: String = "New Exercise", order: Int = 0) {
        self.name = name
        self.order = order
    }
}



