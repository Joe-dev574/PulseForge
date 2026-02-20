//
//  Workout.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI
import SwiftData
internal import HealthKit
import OSLog


/// A persistent model representing a workout routine.
///
/// This class stores workout details, including title, duration, creation/completion dates, and configuration options like rounds.
/// It maintains relationships with Category, Exercise, and History entities for organization and tracking.
/// - Important: All data is stored locally and synced via private iCloud (end-to-end encrypted); no server transmission.
/// - Privacy: Contains user-created workout data
/// - Note: Conforms to SwiftData’s @Model for automatic persistence, querying, and CloudKit compatibility.

@Model
final class Workout {
    /// Unique identifier for the workout, automatically generated as a UUID.
    var id: UUID = UUID()
    
    /// The title of the workout (e.g., "Upper Body A", "5K Tempo Run").
    var title: String = "New Workout"
    
    /// The duration of the last completed session in minutes.
    var lastSessionDuration: Double  = 0.0
    
    /// The date when the workout was created.
    var dateCreated: Date = Date()
    
    /// Optional date when the workout was last completed.
    var dateCompleted: Date? = nil
    
    /// The associated Category for this workout (optional inverse relationship).
    /// - Note: Uses nullify delete to preserve the Category when the Workout is deleted.
    @Relationship(deleteRule: .nullify)
    var category: Category? = nil
    
    /// Flag indicating if rounds mode is enabled for HIIT/circuit workouts.
    var roundsEnabled: Bool = false
    
    /// Number of rounds if rounds mode is enabled (minimum 1).
    var roundsQuantity: Int = 1
    
    /// Optional fastest completion time in minutes, updated from history.
    var fastestTime: Double? = nil
    
    /// Optional AI-generated summary of workout performance and metrics.
    var generatedSummary: String? = nil
    
    /// Array of exercises in this workout.
    /// - Note: Uses cascade delete to remove associated Exercises when the Workout is deleted.
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise]? = []
    
    /// Array of historical sessions for this workout.
    /// - Note: Uses cascade delete to remove associated History entries when the Workout is deleted.
    @Relationship(deleteRule: .cascade, inverse: \History.workout)
    var history: [History]? = []
    
    /// Logger for workout-related events and debugging.
    @Transient
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tnt.PulseForge",
        category: "Workout"
    )
    
    /// Initializes a new workout with the specified properties.
    /// - Parameters:
    ///   - title: The workout title (defaults to "New Workout").
    ///   - exercises: Array of exercises (defaults to empty).
    ///   - lastSessionDuration: Last session duration in minutes (defaults to 0).
    ///   - dateCreated: Creation date (defaults to now).
    ///   - dateCompleted: Optional completion date.
    ///   - category: Optional linked Category.
    ///   - roundsEnabled: Whether rounds are enabled (defaults to false).
    ///   - roundsQuantity: Number of rounds (defaults to 1).
    /// - Important: Validates that title is not empty to ensure data integrity.
    init(
        title: String = "New Workout",
        exercises: [Exercise] = [],
        lastSessionDuration: Double = 0,
        dateCreated: Date = .now,
        dateCompleted: Date? = nil,
        category: Category? = nil,
        roundsEnabled: Bool = false,
        roundsQuantity: Int = 1
    ) {
        guard !title.isEmpty else {
            fatalError("Workout title cannot be empty")
        }
        self.title = title
        self.exercises = exercises
        self.lastSessionDuration = lastSessionDuration
        self.dateCreated = dateCreated
        self.dateCompleted = dateCompleted
        self.category = category
        self.roundsEnabled = roundsEnabled
        self.roundsQuantity = roundsQuantity
    }
    
    /// Sorted array of exercises by order.
    var sortedExercises: [Exercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }
    
    // MARK: - Personal Best Update
    /// Updates the personal best duration based on the shortest valid session duration in history.
    func updateFastestTime() {
        logger.info("Updating fastest time for workout: \(self.title)")
        
        guard let history = history, !history.isEmpty else {
            fastestTime = nil
            logger.info("Journal entries are empty, fastest time set to nil.")
            return
        }
        
        let allDurations = history.map { $0.lastSessionDuration }
        let validDurations = allDurations.filter { $0 > 0 }
        
        fastestTime = validDurations.min()
        logger.info("Updated fastestTime (minutes): \(String(describing: self.fastestTime))")
    }
    
    // MARK: - Effective Exercises
    /// Computed property to return exercises repeated by rounds.
    var effectiveExercises: [Exercise] {
        if roundsEnabled && roundsQuantity > 1 {
            return Array(repeating: sortedExercises, count: roundsQuantity).flatMap { $0 }
        }
        return sortedExercises
    }
    
    // MARK: - Fastest Duration
    /// The fastest session duration in formatted string (e.g., "45:32").
    var formattedFastestTime: String {
        guard let fastest = fastestTime else { return "N/A" }
        return formatDuration(fastest * 60)
    }
    
    // MARK: - Update Generated Summary
    /// Updates the generated summary based on workout history and metrics.
    /// - Parameter context: The ModelContext for saving changes.
    @MainActor func updateGeneratedSummary(in context: ModelContext) {
        logger.info("Updating generatedSummary for workout: \(self.title)")
        
        guard let history = history, !history.isEmpty else {
            generatedSummary = nil
            logger.info("Journal entries are empty, generatedSummary set to nil.")
            return
        }

        let totalSessions = history.count
        let averageDurationInMinutes = history.map { $0.lastSessionDuration }.reduce(0.0, +) / Double(totalSessions)
        let averageDurationInSeconds = averageDurationInMinutes * 60

        if averageDurationInSeconds < 0 {
            logger.warning("Invalid average duration: \(averageDurationInSeconds) seconds")
            generatedSummary = nil
            ErrorManager.shared.present(
                title: "Summary Error",
                message: "Unable to generate workout summary due to invalid duration."
            )
            return
        }

        // Calculate additional metrics
        let fastestTimeFormatted = fastestTime.map { formatDuration($0 * 60) } ?? "N/A"
        let exerciseNames = sortedExercises.map { $0.name }.joined(separator: ", ")

        // Construct professional summary
        var summary = "Workout Performance Overview:\n\n"
        summary += "This workout has been completed \(totalSessions) time(s).\n"
        summary += "Average session duration: \(formatDuration(averageDurationInSeconds)).\n"
        summary += "Fastest recorded time: \(fastestTimeFormatted).\n"
        summary += "Exercises included: \(exerciseNames)."

        generatedSummary = summary
        logger.info("Updated generatedSummary: \(self.generatedSummary ?? "nill")")

        if context.hasChanges {
            do {
                try context.save()
                logger.info("Saved ModelContext after updating generatedSummary.")
            } catch {
                logger.error("Failed to save ModelContext after updating generatedSummary: \(error.localizedDescription)")
                ErrorManager.shared.present(
                    title: "Save Error",
                    message: "Failed to save workout summary: \(error.localizedDescription)"
                )
            }
        }
    }
    // MARK: - Helper for Zone Description
    /// Returns a descriptive string for a heart rate zone.
    /// - Parameter zone: The zone number (1-5).
    /// - Returns: Descriptive label (e.g., "Very Light").
    private func zoneDesc(_ zone: Int) -> String {
        switch zone {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "Unknown"
        }
    }
    // MARK: - Duration Formatting
    /// Formats a duration in seconds into a human-readable string.
    /// Examples: 75 -> "1m 15s", 3661 -> "1h 1m 1s"
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

