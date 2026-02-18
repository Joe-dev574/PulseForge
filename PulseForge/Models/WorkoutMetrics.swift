//
//  WorkoutMetrics.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import Foundation

/// A struct holding all workout metrics, with free and premium separation.
struct WorkoutMetrics: Sendable {
    // Free metrics (available to all users)
    let totalWorkouts: Int?
    let averageSessionDuration: Double?  // In minutes
    let totalWorkoutTime: Double?        // In minutes
    let lastSessionDuration: Double?     // In minutes
    let workoutsPerWeek: Int?
    let fastestTime: Double?             // In minutes
    let currentStreak: Int?
    let longestStreak: Int?
    let exerciseSplits: [SplitTime]?     // Per-exercise durations
    
    // Premium metrics (gated behind subscription)
    let intensityScore: Double?          // 0-100%
    let progressPulseScore: Double?      // 0-100
    let dominantZone: Int?               // 1-5
    let timeInZones: [Int: Double]?      // Zone -> time in seconds (e.g., [1: 120.0])
    let restingHeartRate: Double?        // bpm
    let maxHeartRate: Double?            // bpm
    let estimatedDistance: Double?       // In meters
    
    // Default initializer for empty metrics (e.g., when no data or not premium)
    init(
        totalWorkouts: Int? = nil,
        averageSessionDuration: Double? = nil,
        totalWorkoutTime: Double? = nil,
        lastSessionDuration: Double? = nil,
        workoutsPerWeek: Int? = nil,
        fastestTime: Double? = nil,
        currentStreak: Int? = nil,
        longestStreak: Int? = nil,
        exerciseSplits: [SplitTime]? = nil,
        intensityScore: Double? = nil,
        progressPulseScore: Double? = nil,
        dominantZone: Int? = nil,
        timeInZones: [Int: Double]? = nil,
        restingHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        estimatedDistance: Double? = nil
    ) {
        self.totalWorkouts = totalWorkouts
        self.averageSessionDuration = averageSessionDuration
        self.totalWorkoutTime = totalWorkoutTime
        self.lastSessionDuration = lastSessionDuration
        self.workoutsPerWeek = workoutsPerWeek
        self.fastestTime = fastestTime
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.exerciseSplits = exerciseSplits
        self.intensityScore = intensityScore
        self.progressPulseScore = progressPulseScore
        self.dominantZone = dominantZone
        self.timeInZones = timeInZones
        self.restingHeartRate = restingHeartRate
        self.maxHeartRate = maxHeartRate
        self.estimatedDistance = estimatedDistance
    }
    
    // Helper for "N/A" display in UI (customize as needed)
    func formattedValue(for key: String) -> String {
        switch key {
        case "intensityScore": return intensityScore.map { String(format: "%.0f%%", $0) } ?? "N/A"
        case "progressPulseScore": return progressPulseScore.map { String(format: "%.0f", $0) } ?? "N/A"
        case "dominantZone": return dominantZone.map { "Zone \($0)" } ?? "N/A"
        case "restingHR":  return restingHeartRate.map { "\(Int($0)) bpm" } ?? "N/A"
        default: return "N/A"
        }
    }
}
