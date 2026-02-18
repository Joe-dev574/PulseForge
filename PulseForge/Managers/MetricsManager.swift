//
//  MetricsManager.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI
import SwiftData
import HealthKit
import OSLog
import Observation

@MainActor @Observable
final class MetricsManager {
    // Dependencies
    private let healthKitManager: HealthKitManager
    private let purchaseManager: PurchaseManager
    private let modelContext: ModelContext
    private let errorManager: ErrorManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.tnt.PulseForge", category: "MetricsManager")
    
    // Shared instance
    static let shared = MetricsManager(
        healthKitManager: .shared,
        purchaseManager: .shared,
        modelContext: PulseForgeContainer.container.mainContext,
        errorManager: .shared
    )
    
    private init(
        healthKitManager: HealthKitManager,
        purchaseManager: PurchaseManager,
        modelContext: ModelContext,
        errorManager: ErrorManager
    ) {
        self.healthKitManager = healthKitManager
        self.purchaseManager = purchaseManager
        self.modelContext = modelContext
        self.errorManager = errorManager
    }
    
    // MARK: - Public Fetch Method
    /// Fetches metrics for a specific workout, history, or overall (if both nil).
    func fetchMetrics(for workout: Workout? = nil, history: History? = nil) async -> WorkoutMetrics {
        do {
            // Always calculate free metrics
            let free = try await calculateFreeMetrics(for: workout, history: history)
            
            // Gate premium
            var premium: (intensity: Double?, pulse: Double?, zone: Int?, zones: [Int: Double]?, resting: Double?, maxHR: Double?, distance: Double?) = (nil, nil, nil, nil, nil, nil, nil)
            if purchaseManager.isSubscribed {
                premium = try await calculatePremiumMetrics(for: workout, history: history)
            }
            
            return WorkoutMetrics(
                totalWorkouts: free.totalWorkouts,
                averageSessionDuration: free.avgDuration,
                totalWorkoutTime: free.totalTime,
                lastSessionDuration: free.lastDuration,
                workoutsPerWeek: free.workoutsPerWeek,
                fastestTime: free.fastestTime,
                currentStreak: free.currentStreak,
                longestStreak: free.longestStreak,
                exerciseSplits: free.splits,
                intensityScore: premium.intensity,
                progressPulseScore: premium.pulse,
                dominantZone: premium.zone,
                timeInZones: premium.zones,
                restingHeartRate: premium.resting,
                maxHeartRate: premium.maxHR,
                estimatedDistance: premium.distance
            )
        } catch {
            logger.error("Metrics fetch failed: \(error.localizedDescription)")
            errorManager.present(title: "Metrics Error", message: "Failed to load metrics. Try again.")
            return WorkoutMetrics()  // Empty fallback for UI grace
        }
    }
    
    // MARK: - Free Calculations (Refactor Your Existing Code Here)
    private func calculateFreeMetrics(for workout: Workout?, history: History?) async throws -> (
        totalWorkouts: Int,
        avgDuration: Double,
        totalTime: Double,
        lastDuration: Double,
        workoutsPerWeek: Int,
        fastestTime: Double,
        currentStreak: Int,
        longestStreak: Int,
        splits: [SplitTime]
    ) {
        // Query SwiftData for histories (from your StatsSectionView or MetricsCalculator.fetchWorkoutsPerWeek)
        let histories = try fetchHistories(for: workout)  // Implement below
        
        let totalWorkouts = histories.count
        let totalTime = histories.reduce(0) { $0 + $1.lastSessionDuration }
        let avgDuration = totalWorkouts > 0 ? totalTime / Double(totalWorkouts) : 0
        let lastDuration = histories.first?.lastSessionDuration ?? 0
        let workoutsPerWeek = MetricsCalculator.fetchWorkoutsPerWeek(workout: workout, modelContext: modelContext)  // Reuse your existing func
        let fastestTime = workout?.fastestTime ?? 0
        
        // Streak logic (from ProgressBoardView's heatmap data)
        let sortedDates = histories.sorted { $0.date > $1.date }.map { $0.date }
        let (currentStreak, longestStreak) = calculateStreaks(from: sortedDates)
        
        let splits = history?.splitTimes ?? []  // Or aggregate
        
        return (totalWorkouts, avgDuration, totalTime, lastDuration, workoutsPerWeek, fastestTime, currentStreak, longestStreak, splits)
    }
    
    // MARK: - Premium Calculations (Refactor from HealthKitManager/MetricsCalculator)
    private func calculatePremiumMetrics(for workout: Workout?, history: History?) async throws -> (
        intensity: Double?,
        pulse: Double?,
        zone: Int?,
        zones: [Int: Double]?,
        resting: Double?,
        maxHR: Double?,
        distance: Double?
    ) {
        guard let history = history,
                  let workout = workout else {
                return (nil, nil, nil, nil, nil, nil, nil)
            }
        
        let startDate = history.date
            let endDate = Date(timeInterval: history.lastSessionDuration * 60, since: startDate)
            
            // ←←← THIS IS THE KEY LINE ←←←
            // We let your existing MetricsCalculator do the heavy lifting
            let updatedHistory = try await MetricsCalculator.calculateAdvancedMetrics(
                history: history,
                workout: workout,
                startDate: startDate,
                endDate: endDate,
                modelContext: modelContext,
                authenticationManager: AuthenticationManager.shared,   // or inject if you prefer
                healthKitManager: healthKitManager
            )
            
            // Extract the values we need for the new struct
            let restingHR = await healthKitManager.fetchLatestRestingHeartRateAsync()
            let maxHR = try await healthKitManager.fetchMaxHeartRateAsync()
            
            // Distance fallback (keep your existing helper)
            let distance = healthKitManager.estimateDistance(
                for: workout.category?.categoryColor ?? .STRENGTH,
                durationMinutes: history.lastSessionDuration
            )
            
            return (
                intensity: updatedHistory.intensityScore,
                pulse: updatedHistory.progressPulseScore,
                zone: updatedHistory.dominantZone,
                zones: nil,                    // you can expand later if needed
                resting: restingHR,
                maxHR: maxHR,
                distance: distance
            )
        }
    
    // Helper: Fetch histories from SwiftData
    private func fetchHistories(for workout: Workout?) throws -> [History] {
        var descriptor = FetchDescriptor<History>()
        if let workout {
            descriptor.predicate = #Predicate<History> { $0.workout == workout }
        }
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        return try modelContext.fetch(descriptor)
    }
    // Helper: Calculate streaks from dates
    private func calculateStreaks(from dates: [Date]) -> (current: Int, longest: Int) {
        guard !dates.isEmpty else { return (0, 0) }
        var current = 1
        var longest = 1
        for i in 1..<dates.count {
            if Calendar.current.isDate(dates[i-1], inSameDayAs: dates[i].addingTimeInterval(86400)) {  // Yesterday
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return (current, longest)
    }
}
