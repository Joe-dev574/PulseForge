//
//  MetricsManager.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//
//  Apple App Store Compliance (required for review):
//  - All premium metrics are gated behind subscription (PurchaseManager.isSubscribed).
//  - HealthKit data is read-only for free users and used only for on-device calculations.
//  - Provide a test Apple ID in App Store Connect review notes.
//  - All data stays on-device or uses private iCloud (end-to-end encrypted).
//  - Complies with HealthKit Human Interface Guidelines and App Review 5.1.1.
//

import SwiftUI
import SwiftData
internal import HealthKit
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
    
    // Shared singleton
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
    
    // MARK: - Public API
    func fetchMetrics(for workout: Workout? = nil, history: History? = nil) async -> WorkoutMetrics {
        do {
            let free = try await calculateFreeMetrics(for: workout, history: history)
            
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
            return WorkoutMetrics()
        }
    }
    
    // MARK: - Free Calculations
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
        let histories = try fetchHistories(for: workout)
        
        let totalWorkouts = histories.count
        let totalTime = histories.reduce(0) { $0 + $1.lastSessionDuration }
        let avgDuration = totalWorkouts > 0 ? totalTime / Double(totalWorkouts) : 0
        let lastDuration = histories.first?.lastSessionDuration ?? 0
        let workoutsPerWeek = workout.map { MetricsCalculator.fetchWorkoutsPerWeek(workout: $0, modelContext: modelContext) } ?? 0
        let fastestTime = workout?.fastestTime ?? 0
        
        let sortedDates = histories.sorted { $0.date > $1.date }.map { $0.date }
        let (currentStreak, longestStreak) = calculateStreaks(from: sortedDates)
        
        let splits = history?.splitTimes ?? []
        
        return (totalWorkouts, avgDuration, totalTime, lastDuration, workoutsPerWeek, fastestTime, currentStreak, longestStreak, splits)
    }
    
    // MARK: - Premium Calculations
    private func calculatePremiumMetrics(for workout: Workout?, history: History?) async throws -> (
        intensity: Double?,
        pulse: Double?,
        zone: Int?,
        zones: [Int: Double]?,
        resting: Double?,
        maxHR: Double?,
        distance: Double?
    ) {
        guard let history = history, let workout = workout else {
            return (nil, nil, nil, nil, nil, nil, nil)
        }
        
        let startDate = history.date
        let endDate = Date(timeInterval: history.lastSessionDuration * 60, since: startDate)
        
        let updatedHistory = try await MetricsCalculator.calculateAdvancedMetrics(
            history: history,
            workout: workout,
            startDate: startDate,
            endDate: endDate,
            modelContext: modelContext,
            authenticationManager: AuthenticationManager.shared,
            healthKitManager: healthKitManager
        )
        
        let restingHR = await healthKitManager.fetchLatestRestingHeartRateAsync()
        let maxHR = try await healthKitManager.fetchMaxHeartRateAsync()
        
        let distance = healthKitManager.estimateDistance(
            for: workout.category?.categoryColor ?? .STRENGTH,
            durationMinutes: history.lastSessionDuration
        )
        
        return (
            intensity: updatedHistory.intensityScore,
            pulse: updatedHistory.progressPulseScore,
            zone: updatedHistory.dominantZone,
            zones: nil,
            resting: restingHR,
            maxHR: maxHR,
            distance: distance
        )
    }
    
    private func fetchHistories(for workout: Workout?) throws -> [History] {
        var descriptor = FetchDescriptor<History>()
        if let workout = workout {
            let workoutID = workout.persistentModelID
            descriptor.predicate = #Predicate<History> { history in
                history.workout?.persistentModelID == workoutID
            }
        }
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        return try modelContext.fetch(descriptor)
    }
    
    private func calculateStreaks(from dates: [Date]) -> (current: Int, longest: Int) {
        guard !dates.isEmpty else { return (0, 0) }
        var current = 1
        var longest = 1
        for i in 1..<dates.count {
            if Calendar.current.isDate(dates[i-1], inSameDayAs: dates[i].addingTimeInterval(86400)) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return (current, longest)
    }
}
