//
//  MetricsCalculator.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftData
internal import HealthKit
import Foundation


enum MetricsError: Error {
    case userNotFound
    case noMaxHeartRate
    case noAge
    case fetchFailed(String)
}
/// Called by MetricsManager to compute and attach premium metrics to a History object.
struct MetricsCalculator {
    nonisolated static func calculateAdvancedMetrics(
        history: History,
        workout: Workout,
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext,
        authenticationManager: AuthenticationManager,
        healthKitManager: HealthKitManager
    ) async throws -> History {
        
        let dateInterval = DateInterval(start: startDate, end: endDate)
                
                // Resting HR (used for Intensity Score)
                let restingHR = await healthKitManager.fetchLatestRestingHeartRateAsync()
                
                history.intensityScore = await healthKitManager.calculateIntensityScoreAsync(
                    dateInterval: dateInterval,
                    restingHeartRate: restingHR
                )
                
                // Max HR (used for zones)
                let maxHR = try await healthKitManager.fetchMaxHeartRateAsync()
                
                let (_, dominantZone) = await healthKitManager.calculateTimeInZonesAsync(
                    dateInterval: dateInterval,
                    maxHeartRate: maxHR
                )
                
                history.dominantZone = dominantZone
                
                // Progress Pulse (requires fastest time)
                if let fastestTime = workout.fastestTime {
                    history.progressPulseScore = await healthKitManager.calculateProgressPulseScoreAsync(
                        fastestTime: fastestTime,
                        currentDuration: history.lastSessionDuration,
                        workoutsPerWeek: fetchWorkoutsPerWeek(workout: workout, modelContext: modelContext),
                        targetWorkoutsPerWeek: 3,
                        dominantZone: dominantZone
                    )
                }
                
                return history
            }
    
    // MARK: -  Helpers
        static func fetchWorkoutsPerWeek(
            workout: Workout,
            modelContext: ModelContext
        ) -> Int {
            guard let startOfWeek = Calendar.current.date(
                from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            ) else {
                return 0
            }
            
            let now = Date()
            let targetID = workout.persistentModelID
            
            let predicate = #Predicate<History> { history in
                history.date >= startOfWeek &&
                history.date <= now &&
                history.workout?.persistentModelID == targetID
            }
            
            let descriptor = FetchDescriptor<History>(predicate: predicate)
            
            do {
                return try modelContext.fetchCount(descriptor)
            } catch {
                return 0
            }
        }
    }
