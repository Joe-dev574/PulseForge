//
//  SplitTime.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftData
import Foundation

/// A persistent model representing a time split for an exercise within a workout session.
///
/// This class stores the duration of a specific segment (e.g., an exercise or round) in a workout,
/// along with its order. It maintains optional relationships to Exercise and History for contextual linking.
/// - Important: Durations are stored in seconds for precision; convert as needed for display.
/// - Privacy: Contains timing data that may indirectly relate to health metrics; stored locally and synced via private iCloud (end-to-end encrypted). No server transmission.
/// - Note: Conforms to SwiftData’s @Model for automatic persistence, querying, and CloudKit compatibility.
@Model
final class SplitTime {
    /// Unique identifier for the split time, automatically generated as a UUID.
    var id: UUID = UUID()
    
    /// The duration of the split in seconds (e.g., time spent on an exercise).
    var durationInSeconds: Double = 0.0        // Required: default
    
    /// The order of this split within its parent exercise or history (0-based index).
    var order: Int = 0                         // Required: default
    
    // Optional relationships with proper inverses
    /// The associated Exercise this split belongs to (optional inverse relationship).
    @Relationship(inverse: \Exercise.splitTimes)
    var exercise: Exercise?
    
    /// The associated History entry this split belongs to (optional inverse relationship).
    @Relationship(inverse: \History.splitTimes)
    var history: History?
    
    /// Initializes a new split time with the specified properties.
    /// - Parameters:
    ///   - durationInSeconds: The split duration in seconds (defaults to 0.0).
    ///   - exercise: Optional linked Exercise.
    ///   - history: Optional linked History entry.
    ///   - order: The sequence position (defaults to 0).
    init(durationInSeconds: Double = 0.0, exercise: Exercise? = nil, history: History? = nil, order: Int = 0) {
        self.durationInSeconds = durationInSeconds
        self.exercise = exercise
        self.history = history
        self.order = order
    }
}


