//
//  WorkoutSessionViewModel.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import Foundation
import SwiftUI
import SwiftData
import HealthKit
import OSLog

/// ViewModel for managing the state and logic of an active workout session.
/// This class handles timing, exercise progression, metric calculations, and integration with HealthKit and SwiftData.
/// It is designed to be @MainActor isolated for thread safety in SwiftUI updates.
@Observable @MainActor
final class WorkoutSessionViewModel {
    private let logger = Logger(subsystem: "com.tnt.PulseForge", category: "WorkoutSession")
    
    // Dependencies (made settable after init for injection flexibility)
    let workout: Workout
    var modelContext: ModelContext?
    var purchaseManager: PurchaseManager?
    var healthKitManager: HealthKitManager?
    var authenticationManager: AuthenticationManager?
    var errorManager: ErrorManager?
    var dismissAction: () -> Void = {}
    
    // State properties for workout session
    var secondsElapsed: Double = 0.0
    var exerciseStartTime: Double = 0.0
    var currentExerciseIndex: Int = 0
    var splitTimes: [SplitTime] = []
    var exercisesCompleted: [Exercise] = []
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.tnt.PulseForge.workoutTimer")
    var startDate: Date = .now
    var showMetrics: Bool = false
    var intensityScore: Double?
    var progressPulseScore: Double?
    var dominantZone: Int?
    var finalDisplayedWorkoutDurationSeconds: Double = 0.0
    var collectedHKSamples: [HKSample] = []
    var isCompleting: Bool = false
    var currentDate: Date = .now  // For precise timer updates
    var currentHeartRate: Double = 0.0
    var isRunning: Bool = false
    var isPaused: Bool = false
    var currentRound: Int = 1
    private var hrStreamingTask: Task<Void, Never>?
    
    /// Initializes the ViewModel with the required workout and an optional dismiss action.
    /// - Parameters:
    ///   - workout: The Workout model instance being performed.
    ///   - dismissAction: A closure to dismiss the view upon completion (defaults to no-op).
    init(workout: Workout, dismissAction: @escaping () -> Void = {}) {
        self.workout = workout
        self.dismissAction = dismissAction
    }
    
    // MARK: - Setup
    /// Called when the view appears; resets state and starts the timer.
    /// Accessibility: Ensures initial focus can be set externally.
    func onAppear() {
        startDate = .now
        secondsElapsed = 0.0
        finalDisplayedWorkoutDurationSeconds = 0.0
        splitTimes = []
        exercisesCompleted = []
        currentExerciseIndex = 0
        isRunning = true
        startTimer()
        startHeartRateStreaming()
    }
    
    /// Called when the view disappears; cleans up the timer to prevent leaks.
    func onDisappear() {
        timer?.cancel()
        timer = nil
        hrStreamingTask?.cancel()
    }
    
    // MARK: - Timer Management
    /// Starts a high-precision timer for updating elapsed time.
    /// The timer fires every 1 second for efficient updates, using weak self to avoid retain cycles.
    /// Accessibility: Timer updates trigger accessibility value changes for VoiceOver.
    private func startTimer() {
        // Cancel any existing timer
        timer?.cancel()
        timer = nil

        let newTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        newTimer.schedule(deadline: .now(), repeating: .seconds(1))
        // Use a @Sendable closure that does not capture mutable self directly off-actor.
        newTimer.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentDate = .now
                self.secondsElapsed = self.currentDate.timeIntervalSince(self.startDate)
            }
        }
        newTimer.resume()
        timer = newTimer
    }
    
    func togglePause() {
        isPaused.toggle()
        if isPaused {
            timer?.cancel()
            timer = nil
            if let healthKitManager = healthKitManager {
                Task {
                    await healthKitManager.pausePhoneWorkoutSession()
                }
            }
        } else {
            startTimer()
            if let healthKitManager = healthKitManager {
                Task {
                    await healthKitManager.resumePhoneWorkoutSession()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    /// Computes the display text for the current exercise, including round number if enabled.
    var currentExerciseText: String {
        let roundNumber = workout.roundsEnabled && workout.roundsQuantity > 1
            ? (currentExerciseIndex / workout.sortedExercises.count + 1) : nil
        return roundNumber != nil
            ? "Round \(roundNumber!): \(workout.effectiveExercises[currentExerciseIndex].name)"
            : workout.effectiveExercises[currentExerciseIndex].name
    }
    
    /// Determines the duration to display, preferring final duration post-completion.
    var displayedDuration: Double {
        finalDisplayedWorkoutDurationSeconds > 0 ? finalDisplayedWorkoutDurationSeconds : secondsElapsed
    }
    
    /// Accessibility hint for the primary button, describing its action.
    var primaryButtonAccessibilityHint: String {
        if currentExerciseIndex < workout.effectiveExercises.count - 1 {
            return "Advances to the next exercise: \(workout.effectiveExercises[currentExerciseIndex + 1].name)"
        } else if isCompleting {
            return "Completing workout, please wait"
        } else {
            return "Completes the workout session"
        }
    }
    
    /// Text for the primary button based on workout state.
    var primaryButtonText: String {
        if workout.effectiveExercises.isEmpty {
            return "Finish Workout"
        } else if currentExerciseIndex >= workout.effectiveExercises.count - 1 {
            return "Complete Workout"
        } else {
            return "Next Exercise"
        }
    }
    
    /// Accessibility identifier for the primary button.
    var primaryButtonAccessibilityID: String {
        if workout.effectiveExercises.isEmpty {
            return "completeWorkoutButton"
        } else if currentExerciseIndex >= workout.effectiveExercises.count - 1 {
            return "completeWorkoutButton"
        } else {
            return "nextExerciseButton"
        }
    }
    
    /// Determines if the secondary "End Workout Early" button should be visible.
    var showSecondaryEndButton: Bool {
        !workout.effectiveExercises.isEmpty && currentExerciseIndex < workout.effectiveExercises.count - 1
    }
    
    // MARK: - Actions
    /// Handles the primary button tap: advances exercise or completes workout.
    func primaryButtonAction() async {
        if currentExerciseIndex < workout.effectiveExercises.count - 1 {
            advanceToNextExercise()
        } else {
            await completeWorkout()
        }
    }
    
    /// Advances to the next exercise, recording split time.
    private func advanceToNextExercise() {
        let exerciseDuration = secondsElapsed - exerciseStartTime
        let currentSplit = SplitTime(durationInSeconds: exerciseDuration, order: currentExerciseIndex)
        splitTimes.append(currentSplit)
        exercisesCompleted.append(workout.effectiveExercises[currentExerciseIndex])
        currentExerciseIndex += 1
        exerciseStartTime = secondsElapsed
    }
    
    /// Completes the workout session, calculating metrics and saving data.
    /// - Parameter early: Indicates if the workout is ending prematurely.
    /// This function sets isCompleting to true during processing and resets it afterward.
    /// Accessibility: Button is disabled during completion to prevent multiple taps.
    func completeWorkout(early: Bool = false) async {
        guard !isCompleting else { return }
        guard let modelContext = modelContext,
              let healthKitManager = healthKitManager,
              let authenticationManager = authenticationManager,
              let errorManager = errorManager else {
            logger.error("Dependencies not set for completeWorkout")
            return
        }
        isCompleting = true
        
        timer?.cancel()
        let endDate = Date()
        secondsElapsed = endDate.timeIntervalSince(startDate)
        finalDisplayedWorkoutDurationSeconds = secondsElapsed
        
        if !workout.effectiveExercises.isEmpty {
            let lastDuration = secondsElapsed - exerciseStartTime
            let lastSplit = SplitTime(durationInSeconds: lastDuration, order: currentExerciseIndex)
            splitTimes.append(lastSplit)
            exercisesCompleted.append(workout.effectiveExercises[currentExerciseIndex])
        }
        
        do {
            let history = History(date: startDate, lastSessionDuration: secondsElapsed / 60)
            if !workout.effectiveExercises.isEmpty {
                history.splitTimes = splitTimes
            }
            let updatedHistory = try await MetricsCalculator.calculateAdvancedMetrics(
                history: history,
                workout: workout,
                startDate: startDate,
                endDate: endDate,
                modelContext: modelContext,
                authenticationManager: authenticationManager,
                healthKitManager: healthKitManager
            )
            if healthKitManager.isWriteAuthorized {
                let samples = try await createHealthKitSamples(for: updatedHistory, workoutStartDate: startDate, workoutEndDate: endDate)
                collectedHKSamples.append(contentsOf: samples)
                _ = try await healthKitManager.saveWorkout(workout, history: updatedHistory, samples: collectedHKSamples)
            }
            workout.history?.append(updatedHistory)
            workout.updateFastestTime()
            workout.updateGeneratedSummary(in: modelContext)
            try modelContext.save()
            dismissAction()
        } catch {
            logger.error("Error completing workout: \(error.localizedDescription)")
            errorManager.present(title: "Error", message: error.localizedDescription)
        }
        isCompleting = false
    }
    
    // MARK: - Formatting
    /// Formats seconds into a MM:SS string for display.
    /// - Parameter seconds: The total seconds to format.
    /// - Returns: A string in the format "MM:SS".
    func formattedTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    // MARK: - Heart Rate Streaming (kept your async stream - no Combine needed)
        private func startHeartRateStreaming() {
            guard let healthKitManager = healthKitManager,
                  purchaseManager?.isSubscribed == true,
                  healthKitManager.isReadAuthorized else { return }
            
            hrStreamingTask = Task {
                do {
                    for try await sample in healthKitManager.streamHeartRate() {
                        let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        self.currentHeartRate = bpm
                    }
                } catch {
                    logger.error("HR streaming error: \(error.localizedDescription)")
                }
            }
        }
    // MARK: - HealthKit Samples (Category-specific implementation with MET and weight)
    /// Asynchronously creates an array of HKSample objects for the workout, including energy, heart rate, and category-specific metrics.
    /// - Parameters:
    ///   - history: The History object containing workout details.
    ///   - workoutStartDate: The start date of the workout.
    ///   - workoutEndDate: The end date of the workout.
    /// - Returns: An array of HKSample.
    /// - Throws: HealthKit or fetch errors.
    /// Accessibility: Samples are time-bound for accurate Health app display.
    private func createHealthKitSamples(for history: History, workoutStartDate: Date, workoutEndDate: Date) async throws -> [HKSample] {
        var samples: [HKSample] = []
        
        // Include active energy sample, calculated with category MET and user weight
        if let energySample = try await createActiveEnergySample(for: history, start: workoutStartDate, end: workoutEndDate) {
            samples.append(energySample)
        }
        
        // Fetch and include heart rate samples for accuracy
        let heartRateSamples = try await fetchHeartRateSamples(start: workoutStartDate, end: workoutEndDate)
        samples.append(contentsOf: heartRateSamples)
        
        // Add category-specific samples (e.g., distance) based on CategoryColor
        if let categoryColor = workout.category?.categoryColor {
            switch categoryColor {
            case .RUN, .WALK, .HIKING:
                // Fetch or estimate distance for running/walking/hiking
                let distanceType = HKQuantityType(.distanceWalkingRunning)
                let totalDistanceMeters = try await fetchCumulativeQuantity(type: distanceType, start: workoutStartDate, end: workoutEndDate)
                
                let distanceMeters = totalDistanceMeters > 0 ? totalDistanceMeters : estimateDistance(for: categoryColor, durationMinutes: history.lastSessionDuration)
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: workoutStartDate,
                    end: workoutEndDate
                )
                samples.append(distanceSample)
                
            case .CYCLING:
                // Fetch or estimate cycling distance
                let distanceType = HKQuantityType(.distanceCycling)
                let totalDistanceMeters = try await fetchCumulativeQuantity(type: distanceType, start: workoutStartDate, end: workoutEndDate)
                
                let distanceMeters = totalDistanceMeters > 0 ? totalDistanceMeters : estimateDistance(for: categoryColor, durationMinutes: history.lastSessionDuration)
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: workoutStartDate,
                    end: workoutEndDate
                )
                samples.append(distanceSample)
                
            case .SWIMMING:
                // Fetch or estimate swimming distance
                let distanceType = HKQuantityType(.distanceSwimming)
                let totalDistanceMeters = try await fetchCumulativeQuantity(type: distanceType, start: workoutStartDate, end: workoutEndDate)
                
                let distanceMeters = totalDistanceMeters > 0 ? totalDistanceMeters : estimateDistance(for: categoryColor, durationMinutes: history.lastSessionDuration)
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: workoutStartDate,
                    end: workoutEndDate
                )
                samples.append(distanceSample)
                
            case .ROWING:
                // Fetch or estimate rowing distance (proxy with .distanceWalkingRunning)
                let distanceType = HKQuantityType(.distanceWalkingRunning)
                let totalDistanceMeters = try await fetchCumulativeQuantity(type: distanceType, start: workoutStartDate, end: workoutEndDate)
                
                let distanceMeters = totalDistanceMeters > 0 ? totalDistanceMeters : estimateDistance(for: categoryColor, durationMinutes: history.lastSessionDuration)
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: workoutStartDate,
                    end: workoutEndDate
                )
                samples.append(distanceSample)
                
            default:
                // No additional distance samples for other categories
                break
            }
        }
        
        return samples
    }
    
    /// Asynchronously creates an active energy HKQuantitySample using MET, user weight, and duration.
    /// - Parameters:
    ///   - history: The History object.
    ///   - start: Start date.
    ///   - end: End date.
    /// - Returns: Optional HKQuantitySample.
    /// - Throws: Fetch errors.
    private func createActiveEnergySample(for history: History, start: Date, end: Date) async throws -> HKQuantitySample? {
        // Fetch user weight from HealthMetrics
        let userWeightKg = try await fetchUserWeight() ?? 70.0  // Default to 70kg if unavailable
        
        // Use category-specific MET value
        let metValue = workout.category?.categoryColor.metValue ?? 5.0  // Fallback if no category
        
        // Calculate time in hours
        let timeHours = history.lastSessionDuration / 60.0
        
        // Accurate energy calculation: Calories = MET * weight (kg) * time (hours)
        let energyKcal = metValue * userWeightKg * timeHours
        
        let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: energyKcal)
        return HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: energyQuantity,
            start: start,
            end: end
        )
    }
    
    // Helper to fetch user weight from HealthMetrics using modelContext and authenticationManager
    /// Fetches the user's weight from HealthMetrics.
    /// - Returns: Weight in kg, or nil if not found.
    /// - Throws: Fetch errors.
    private func fetchUserWeight() async throws -> Double? {
        guard let currentUserId = authenticationManager?.currentUser?.appleUserId else {
            logger.error("No current user ID available")
            return nil
        }
        
        let predicate = #Predicate<User> { $0.appleUserId == currentUserId }
        var descriptor = FetchDescriptor<User>(predicate: predicate)
        descriptor.relationshipKeyPathsForPrefetching = [\User.healthMetrics]
        
        guard let user = try modelContext?.fetch(descriptor).first else {
            logger.error("User not found for ID: \(currentUserId)")
            return nil
        }
        
        return user.healthMetrics?.weight
    }
    
    // Helper to fetch heart rate samples from HealthKit during the workout interval
    /// Fetches heart rate samples from HealthKit.
    /// - Parameters:
    ///   - start: Start date.
    ///   - end: End date.
    /// - Returns: Array of HKSample.
    /// - Throws: Query errors.
    private func fetchHeartRateSamples(start: Date, end: Date) async throws -> [HKSample] {
        guard let healthKitManager = healthKitManager else {
            throw HealthKitError.dataNotFound("HealthKit manager unavailable")
        }
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            logger.error("Heart rate type unavailable")
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let hrSamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: hrSamples)
            }
            healthKitManager.healthStore.execute(query)
        }
    }
    
    // Helper to fetch cumulative quantity from HealthKit
    /// Fetches cumulative quantity (e.g., distance) from HealthKit.
    /// - Parameters:
    ///   - type: The HKQuantityType.
    ///   - start: Start date.
    ///   - end: End date.
    /// - Returns: Cumulative value in meters.
    /// - Throws: Query errors.
    private func fetchCumulativeQuantity(type: HKQuantityType, start: Date, end: Date) async throws -> Double {
        guard let healthKitManager = healthKitManager else {
            throw HealthKitError.dataNotFound("HealthKitManager is missing")
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let total = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0.0
                continuation.resume(returning: total)
            }
            healthKitManager.healthStore.execute(query)
        }
    }
    
    // Helper for distance estimation fallback (category-specific assumptions)
    /// Estimates distance for fallback when no real data is available.
    /// - Parameters:
    ///   - categoryColor: The CategoryColor enum value.
    ///   - durationMinutes: Duration in minutes.
    /// - Returns: Estimated distance in meters.
    private func estimateDistance(for categoryColor: CategoryColor, durationMinutes: Double) -> Double {
        let hours = durationMinutes / 60.0
        switch categoryColor {
        case .RUN: return hours * 8000.0  // ~8 km/h average running pace
        case .WALK: return hours * 5000.0  // ~5 km/h walking pace
        case .HIKING: return hours * 4000.0  // ~4 km/h hiking pace
        case .CYCLING: return hours * 20000.0  // ~20 km/h cycling pace
        case .SWIMMING: return hours * 1500.0  // ~1.5 km/h swimming pace
        case .ROWING: return hours * 6000.0  // ~6 km/h rowing pace
        default: return 0.0
        }
    }
}


