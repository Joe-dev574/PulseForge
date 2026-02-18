//
//  History.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI
import SwiftData
import Foundation

/// A persistent model representing a historical workout session.
///
/// This class stores details of completed workouts, including timing, notes, and performance metrics.
/// It maintains relationships with Exercise, SplitTime, and Workout entities for comprehensive data tracking.
/// - Important: All data is stored locally and synced via private iCloud (end-to-end encrypted); no server transmission.
/// - Privacy: Contains potentially sensitive health-related notes and metrics; ensure user consent and secure handling.
/// - Note: Conforms to SwiftData’s @Model for automatic persistence, querying, and CloudKit compatibility.

@Model
final class History {
    /// Unique identifier for the history entry, automatically generated as a UUID.
    var id: UUID = UUID()
    
    /// The date and time when the workout session was completed.
    var date: Date = Date()
    
    /// The duration of the last session in minutes.
    var lastSessionDuration: Double = 0.0
    
    /// Optional user notes about the workout (e.g., "Felt strong today" or performance details).
    var notes: String?
    
    /// Array of exercises completed during the session.
    var exercisesCompleted: [Exercise] = []
   
    
    /// Array of split times recorded during the workout.
    /// - Note: Uses cascade delete to remove associated SplitTimes when the History is deleted.
    @Relationship(deleteRule: .cascade)
    var splitTimes: [SplitTime]? = []
    
    /// The associated Workout this history entry belongs to (optional inverse relationship).
    /// - Note: Uses nullify delete to preserve the Workout when the History is deleted.
    @Relationship(deleteRule: .nullify)
    var workout: Workout?
    
    /// Optional intensity score for the session (0-100 scale).
    var intensityScore: Double?
    
    /// Optional Progress Pulse score for the session (0-100 scale, derived from performance metrics).
    var progressPulseScore: Double?
    
    /// Optional dominant heart rate zone during the session (e.g., 1-5).
    var dominantZone: Int?
    
    /// Initializes a new history entry with the specified properties.
    /// - Parameters:
    ///   - date: The completion date (defaults to now).
    ///   - lastSessionDuration: Session duration in minutes (defaults to 0).
    ///   - notes: Optional workout notes.
    ///   - exercisesCompleted: Array of completed exercises (defaults to empty).
    ///   - splitTimes: Array of split times (defaults to empty).
    ///   - intensityScore: Optional intensity score.
    ///   - progressPulseScore: Optional Progress Pulse score.
    ///   - dominantZone: Optional dominant HR zone.
    init(
        date: Date = .now,
        lastSessionDuration: Double = 0,
        notes: String? = nil,
        exercisesCompleted: [Exercise] = [],
        splitTimes: [SplitTime] = [],
        intensityScore: Double? = nil,
        progressPulseScore: Double? = nil,
        dominantZone: Int? = nil
    ) {
        self.date = date
        self.lastSessionDuration = lastSessionDuration
        self.notes = notes
        self.exercisesCompleted = exercisesCompleted
        self.splitTimes = splitTimes
        self.intensityScore = intensityScore
        self.progressPulseScore = progressPulseScore
        self.dominantZone = dominantZone
    }
    
    // MARK: - Computed Display Properties (Usable in #Predicate)
        
    /// Full formatted duration (e.g., "45:32" or "1:23:45").
    /// - Note: Converts minutes to seconds for formatting; handles hours if duration >= 60 minutes.
    var formattedDuration: String {
        let seconds = lastSessionDuration * 60 // Convert minutes to seconds
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds < 3600 ? [.minute, .second] : [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "00:00"
    }
        
    /// Concise duration for compact displays (e.g., "45.3m", "1.2h", "32.1s").
    /// - Note: Automatically selects unit based on duration size.
    var formattedDurationConcise: String {
        let seconds = lastSessionDuration * 60
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else if seconds < 3600 {
            return String(format: "%.1fm", seconds / 60)
        } else {
            return String(format: "%.1fh", seconds / 3600)
        }
    }
        
    /// Short time string (e.g., "2:30 PM").
    var shortTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
        
    /// Medium date string (e.g., "Dec 23, 2025").
    var mediumDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
        
    /// Combined date and time for list headers (e.g., "Dec 23, 2025 · 2:30 PM").
    var dateAndTime: String {
        "\(mediumDate) · \(shortTime)"
    }
}

