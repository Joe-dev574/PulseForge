//
//  HealthKitManager.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import Foundation
import HealthKit
import OSLog
import SwiftUI
import SwiftData
import Observation

#if os(watchOS)
import WatchConnectivity  // Optional: for future phone-watch comms if needed
#endif

/// Centralized manager for HealthKit interactions in PulseForge.
///
/// This class handles authorization, workout sessions (iPhone and premium Watch), live data streaming,
/// and advanced metrics like heart rate zones and Progress Pulse scores. It supports async/await for modern usage.
///
/// - Important: Complies with Apple's HealthKit guidelines:
///   - Requests only necessary permissions.
///   - All data is processed on-device or via private iCloud sync; no server transmission.
///   - Users must explicitly authorize access; explain in UI (e.g., "We need Health access to track workouts and metrics").
///   - For App Review: Provide test accounts and demo how data is used/protected.
///   - Handle denial gracefully with fallbacks (e.g., manual entry for body weight).
///
/// For production:
/// - Test on physical devices (simulator has limited HealthKit support).
/// - Monitor for HKError codes and log anonymously (no PII).
/// - Integrate with ErrorManager for user-facing alerts.

@MainActor @Observable
final class HealthKitManager {
    // MARK: - SINGLETON
    /// Shared singleton instance.
    static let shared = HealthKitManager()
    
    // MARK: - Dependencies
    /// The underlying HealthKit store.
    let healthStore = HKHealthStore()
    
    // MARK: - Private Properties
    /// Logger for HealthKit-related events.
    private let logger = Logger(subsystem: "com.tnt.PulseForge", category: "HealthKit")
    
    // MARK: - OBSERVABLE STATE
    /// Whether read permissions are granted.
    var isReadAuthorized = false
    /// Whether write permissions are granted.
    var isWriteAuthorized = false
    /// Current authorization request status.
    var authorizationRequestStatus: HKAuthorizationRequestStatus = .unknown
  
    // MARK: - Workout Session State
    /// Active workout session (shared for iPhone/Watch where applicable).
    private var workoutSession: HKWorkoutSession?
    
    // iPhone-specific
    private var phoneWorkoutBuilder: HKWorkoutBuilder?
        
    // Premium Watch-specific
    #if os(watchOS)
    private var watchWorkoutSession: HKWorkoutSession?
    private var watchWorkoutBuilder: HKWorkoutBuilder?
    #endif
  
    // MARK: - Initialization
    /// Private initializer. Does not auto-check authorization—call requestAndUpdateAuthorizationIfNeeded() when needed.
    private init() {}
    
    // MARK: - HealthKit Types
    /// Types requested for reading (e.g., heart rate, workouts).
    private var typesToRead: Set<HKObjectType> {
        Set([
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.bodyMass),
            HKQuantityType(.height),
            HKObjectType.workoutType(),
            HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!,
            HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!
        ])
    }
        
    /// Types requested for writing (e.g., workouts, energy burned).
    private var typesToWrite: Set<HKSampleType> {
        Set([
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
        ])
    }
    
    // MARK: - Authorization
    /// Requests HealthKit authorization if not already determined, then updates status.
    ///
    /// - Throws: HealthKitError or AppError if request fails.
    /// - Note: Call this just-in-time (e.g., on WorkoutListScreen appearance) to avoid early errors.
    func requestAndUpdateAuthorizationIfNeeded() async throws {
        if authorizationRequestStatus == .shouldRequest {
            try await requestAuthorization()
        }
        await updateAuthorizationStatus()
    }
    
    /// Updates the authorization status by checking read/write capabilities.
    ///
    /// Uses dummy queries/builders to verify permissions accurately.
    func updateAuthorizationStatus() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationRequestStatus = .unknown
            isReadAuthorized = false
            isWriteAuthorized = false
            return
        }
            
        // Accurately check read authorization by attempting a dummy query
        do {
            _ = try await fetchLatestQuantity(typeIdentifier: .height, unit: .meter())
            isReadAuthorized = true
            logger.debug("Read authorization confirmed")
        } catch let error as HKError where error.code == .errorAuthorizationDenied || error.code == .errorAuthorizationNotDetermined {
            isReadAuthorized = false
            logger.warning("Read authorization denied or undetermined")
        } catch {
            logger.error("Read authorization check failed: \(error.localizedDescription)")
            isReadAuthorized = false
        }
        // Write authorization check using non-persistent dummy builder
        do {
            let config = HKWorkoutConfiguration()
            config.activityType = .other  // Neutral type for testing
            config.locationType = .unknown
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
            try await builder.beginCollection(at: Date())
            builder.discardWorkout()  // Discard without saving
            isWriteAuthorized = true
            logger.debug("Write authorization confirmed")
        } catch let error as HKError where error.code == .errorAuthorizationDenied || error.code == .errorAuthorizationNotDetermined {
            isWriteAuthorized = false
            logger.warning("Write authorization denied or undetermined")
        } catch {
            logger.error("Write authorization check failed: \(error.localizedDescription)")
            isWriteAuthorized = false
        }
        
        // Update request status (now integrated)
        do {
            authorizationRequestStatus = try await getRequestStatusForAuthorization()
            logger.debug("Authorization request status updated: \(self.authorizationRequestStatus.rawValue)")
        } catch {
            logger.error("Failed to get authorization request status: \(error.localizedDescription)")
            authorizationRequestStatus = .unknown
        }
    }
    
    // MARK: GET REQUEST STATUS
    /// Retrieves the authorization request status asynchronously.
    private func getRequestStatusForAuthorization() async throws -> HKAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: typesToWrite, read: typesToRead) { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
   
    // MARK: REQUEST AUTHORIZATION
    /// Requests HealthKit permissions for read/write types.
    ///
    /// - Throws: `AppError.healthKitUnavailable` if HealthKit is not supported.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AppError.healthKitUnavailable
        }
        logger.info("Requesting HealthKit permissions...")
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        await updateAuthorizationStatus()
        logger.info("HealthKit permissions requested.")
    }
    // MARK: - iPhone Workout Session (Freemium)
    /// Starts a workout session on iPhone.
    ///
    /// - Parameter workout: The app's Workout model.
    func startPhoneWorkoutSession(workout: Workout) async {
        guard let activityType = workout.category?.categoryColor.hkActivityType else { return }
        do {
            let config = HKWorkoutConfiguration()
            config.activityType = activityType
            config.locationType = .unknown
            
            if #available(iOS 26.0, *) {
                workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
                workoutSession?.startActivity(with: Date())
            } else {
                // Fallback for iOS 18.6 to 25.x: Use builder without session for data collection
                logger.warning("Using fallback workout builder without session for iOS < 26.0")
            }
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
            try await builder.beginCollection(at: Date())
            phoneWorkoutBuilder = builder
            logger.info("iPhone workout session started")
        } catch {
            logger.error("Failed to start iPhone session: \(error.localizedDescription)")
        }
    }
    
    /// Pauses the active iPhone workout session if available.
    func pausePhoneWorkoutSession() async {
        if #available(iOS 26.0, *) {
            workoutSession?.pause()
            logger.info("iPhone workout session paused")
        } else {
            // No-op for lower iOS versions without session
            logger.debug("Pause not supported on iOS < 26.0")
        }
    }
    
    /// Resumes the active iPhone workout session if available.
    func resumePhoneWorkoutSession() async {
        if #available(iOS 26.0, *) {
            workoutSession?.resume()
            logger.info("iPhone workout session resumed")
        } else {
            // No-op for lower iOS versions without session
            logger.debug("Resume not supported on iOS < 26.0")
        }
    }
    
    /// Ends the active iPhone workout session and saves the workout.
    func endPhoneWorkoutSession() async {
        do {
            if #available(iOS 26.0, *) {
                workoutSession?.end()
            }
            try await phoneWorkoutBuilder?.endCollection(at: Date())
            let result = try await phoneWorkoutBuilder?.finishWorkout()
            logger.info("iPhone workout saved: \(result != nil ? "Success" : "Failure")")
        } catch {
            logger.error("Failed to end iPhone session: \(error.localizedDescription)")
        }
        workoutSession = nil
        phoneWorkoutBuilder = nil
    }
    
    // MARK: - Watch Workout Session (Premium)
    #if os(watchOS)
    /// Starts a workout session on Apple Watch (premium only).
    ///
    /// - Parameter workout: The app's Workout model.
    func startWatchWorkoutSession(workout: Workout) async {
        guard let activityType = workout.category?.categoryColor.hkActivityType else { return }
        do {
            let config = HKWorkoutConfiguration()
            config.activityType = activityType
            config.locationType = .unknown
            
            watchWorkoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
            try await builder.beginCollection(at: Date())
            watchWorkoutBuilder = builder
            watchWorkoutSession?.startActivity(with: Date())
            logger.info("Watch workout session started")
        } catch {
            logger.error("Failed to start Watch session: \(error.localizedDescription)")
        }
    }
    
    /// Pauses the active Watch workout session.
    func pauseWatchWorkoutSession() async {
        watchWorkoutSession?.pause()
        logger.info("Watch workout session paused")
    }
    
    /// Resumes the active Watch workout session.
    func resumeWatchWorkoutSession() async {
        watchWorkoutSession?.resume()
        logger.info("Watch workout session resumed")
    }
    
    /// Ends the active Watch workout session and saves the workout.
    func endWatchWorkoutSession() async {
        do {
            watchWorkoutSession?.end()
            try await watchWorkoutBuilder?.endCollection(at: Date())
            let result = try await watchWorkoutBuilder?.finishWorkout()
            logger.info("Watch workout saved: \(result != nil ? "Success" : "Failure")")
        } catch {
            logger.error("Failed to end Watch session: \(error.localizedDescription)")
        }
        watchWorkoutSession = nil
        watchWorkoutBuilder = nil
    }
    #endif
    
    // MARK: - Fetch Latest Quantity (Generic)
    /// Fetches the latest value for a HealthKit quantity type asynchronously.
    ///
    /// - Parameters:
    ///   - typeIdentifier: The HKQuantityTypeIdentifier to query.
    ///   - unit: The HKUnit for the returned value.
    /// - Returns: The latest quantity value, or nil if none found.
    /// - Throws: HealthKitError on query failure or data unavailability.
    func fetchLatestQuantity(
        typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: typeIdentifier) else {
            throw HealthKitError.dataNotFound(typeIdentifier.rawValue)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
                if let error = error {
                    self?.logger.error("Failed to fetch \(typeIdentifier.rawValue): \(error.localizedDescription)")
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Fetch Health Metrics
    /// Fetches core health metrics: weight (kg), height (m), max HR (bpm).
    ///
    /// - Returns: Tuple of (weight, height, maxHR), with optionals for unavailable data.
    /// - Throws: HealthKitError on query failures.
    func fetchHealthMetrics() async throws -> (Double?, Double?, Double?) {
        async let weight = try? await fetchLatestQuantity(typeIdentifier: .bodyMass, unit: .gramUnit(with: .kilo))
        async let height = try? await fetchLatestQuantity(typeIdentifier: .height, unit: .meter())
        async let maxHR = try? await fetchLatestQuantity(typeIdentifier: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()))  // Note: For max HR, consider a statistics query for maximum instead of latest.
        
        return await (weight, height, maxHR)
    }
    
    // MARK: RESTING HEART RATE
    /// Fetches the latest resting heart rate from HealthKit.
    ///
    /// - Parameter completion: Callback with the heart rate in bpm or error.
    func fetchLatestRestingHeartRate(completion: @escaping (Double?, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available on this device")
            completion(nil, HealthKitError.healthDataUnavailable)
            return
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            logger.error("Resting heart rate type is not available")
            completion(nil, HealthKitError.heartRateDataUnavailable)
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                self?.logger.error("Failed to fetch resting heart rate: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                self?.logger.info("No resting heart rate samples found")
                completion(nil, nil)
                return
            }
            
            let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            self?.logger.info("Fetched resting heart rate: \(heartRate) bpm")
            completion(heartRate, nil)
        }
        
        logger.debug("Executing resting heart rate query")
        healthStore.execute(query)
    }
    
    // MARK: CALCULATE INTENSITY SCORE
    /// Calculates an intensity score based on average heart rate during a date interval.
    ///
    /// - Parameters:
    ///   - dateInterval: The time period for the calculation.
    ///   - restingHeartRate: User's resting HR.
    ///   - completion: Callback with the intensity percentage (0-100) or error.
    func calculateIntensityScore(dateInterval: DateInterval, restingHeartRate: Double?, completion: @escaping (Double?, Error?) -> Void) {
        guard let restingHR = restingHeartRate, HKHealthStore.isHealthDataAvailable(), let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            logger.error("HealthKit unavailable or invalid inputs")
            completion(nil, HealthKitError.healthDataUnavailable)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: dateInterval.start, end: dateInterval.end, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: hrType, quantitySamplePredicate: predicate, options: .discreteAverage) { [weak self] _, result, error in
            if let error = error {
                self?.logger.error("Failed to fetch average HR: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let averageHR = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) else {
                self?.logger.info("No average HR data available")
                completion(nil, nil)
                return
            }

            Task { [weak self] in
                guard let self = self else { completion(nil, nil); return }
                do {
                    let (_, _, maxHR) = try await self.fetchHealthMetrics()
                    guard let maxHR = maxHR else {
                        completion(nil, HealthKitError.noMaxHeartRateData)
                        return
                    }
                    let intensity = ((averageHR - restingHR) / (maxHR - restingHR)) * 100
                    let clampedIntensity = max(0, min(100, intensity))
                    self.logger.info("Calculated intensity score: \(clampedIntensity)")
                    completion(clampedIntensity, nil)
                } catch {
                    self.logger.error("Failed to fetch health metrics: \(error.localizedDescription)")
                    completion(nil, error)
                }
            }
        }
        healthStore.execute(query)
    }
    // MARK: CALCULATE PROGRESS PULSE SCORE
    public func calculateProgressPulseScore(fastestTime: Double,
                                            currentDuration: Double,
                                            workoutsPerWeek: Int,
                                            targetWorkoutsPerWeek: Int,
                                            dominantZone: Int?) -> Double? {
        logger.info("[HealthKitManager] calculateProgressPulseScore called.")
        var score = 50.0
        
        if currentDuration <= fastestTime && fastestTime > 0{
            score += 15
            logger.debug("[ProgressPulse] Beat or matched PR: +15 points. Current: \(currentDuration), PB: \(fastestTime)")
        } else {
            logger.debug("[ProgressPulse] Slower than PR. Current: \(currentDuration), PB: \(fastestTime)")
        }
        
        let frequencyPoints = Double(min(workoutsPerWeek, targetWorkoutsPerWeek) * 5)
        score += frequencyPoints
        logger.debug("[ProgressPulse] Frequency points: +\(frequencyPoints) (Workouts this week: \(workoutsPerWeek), Target: \(targetWorkoutsPerWeek))")
        
        if let zone = dominantZone {
            if zone >= 4 {
                score += 10
                logger.debug("[ProgressPulse] High intensity (Zone \(zone)): +10 points")
            } else if zone == 3 {
                score += 5
                logger.debug("[ProgressPulse] Moderate intensity (Zone \(zone)): +5 points")
            } else {
                logger.debug("[ProgressPulse] Low intensity (Zone \(zone)): +0 points")
            }
        } else {
            logger.debug("[ProgressPulse] Dominant zone not available: +0 points for intensity.")
        }
        
        let finalScore = min(max(score, 0), 100)
        logger.info("[HealthKitManager] Progress Pulse score calculated: \(finalScore)")
        return finalScore
    }
    
    public func calculateProgressPulseScoreAsync(fastestTime: Double,
                                                     currentDuration: Double,
                                                     workoutsPerWeek: Int,
                                                     targetWorkoutsPerWeek: Int,
                                                     dominantZone: Int?) async -> Double {
        return calculateProgressPulseScore(fastestTime: fastestTime,
                                               currentDuration: currentDuration,
                                               workoutsPerWeek: workoutsPerWeek,
                                               targetWorkoutsPerWeek: targetWorkoutsPerWeek,
                                                 dominantZone: dominantZone) ?? 50
        }
    // MARK: - Time in Heart Rate Zones
    /// Calculates time spent in each heart rate zone during a date interval.
    ///
    /// - Parameters:
    ///   - dateInterval: The time period.
    ///   - maxHeartRate: User's max HR.
    ///   - completion: Callback with time per zone (seconds), dominant zone, or error.
    func calculateTimeInZones(dateInterval: DateInterval, maxHeartRate: Double?, completion: @escaping ([Int: Double]?, Int?, Error?) -> Void) {
        guard let maxHR = maxHeartRate, let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(nil, nil, HealthKitError.noMaxHeartRateData)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: dateInterval.start, end: dateInterval.end, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { [weak self] _, samples, error in
            if let error = error {
                self?.logger.error("Failed to fetch HR samples: \(error.localizedDescription)")
                completion(nil, nil, error)
                return
            }
            
            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                completion(nil, nil, nil)
                return
            }
            
            var timeInZones: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
            var previousTime = dateInterval.start
            
            for sample in samples {
                let hr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let duration = sample.endDate.timeIntervalSince(previousTime)
                let zone = Self.calculateHeartRateZone(hr: hr, maxHR: maxHR)
                timeInZones[zone, default: 0] += duration
                previousTime = sample.endDate
            }
            
            let dominantZone = timeInZones.max(by: { $0.value < $1.value })?.key
            completion(timeInZones, dominantZone, nil)
        }
        healthStore.execute(query)
    }
    
    // MARK: - Heart Rate Zone Helper (nonisolated)
    /// Pure function to compute heart rate zone without requiring main-actor isolation.
    /// Zones are 1-5 based on percentage of max HR. Adjust thresholds to match app logic.
    nonisolated private static func calculateHeartRateZone(hr: Double, maxHR: Double) -> Int {
        guard maxHR > 0 else { return 1 }
        let pct = hr / maxHR
        switch pct {
        case ..<0.6:  return 1
        case ..<0.7:  return 2
        case ..<0.8:  return 3
        case ..<0.9:  return 4
        default:       return 5
        }
    }
    
    // MARK: - Stream Heart Rate
    /// Streams live heart rate data during workouts.
    ///
    /// - Returns: AsyncStream of HKQuantitySample for heart rate.
    /// - Throws: HealthKitError if streaming unavailable.
    func streamHeartRate() -> AsyncThrowingStream<HKQuantitySample, Error> {
        AsyncThrowingStream { continuation in
            guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
                continuation.finish(throwing: HealthKitError.heartRateDataUnavailable)
                return
            }
            
            let query = HKAnchoredObjectQuery(type: hrType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                if let samples = samples as? [HKQuantitySample] {
                    for sample in samples {
                        continuation.yield(sample)
                    }
                }
            }
            query.updateHandler = { _, samples, _, _, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                if let samples = samples as? [HKQuantitySample] {
                    for sample in samples {
                        continuation.yield(sample)
                    }
                }
            }
            healthStore.execute(query)
            continuation.onTermination = { _ in
                self.healthStore.stop(query)
            }
        }
    }
    
    // MARK: - Async Wrappers (Added for centralization and async/await support)
    /// Async wrapper for fetchLatestRestingHeartRate.
    func fetchLatestRestingHeartRateAsync() async -> Double? {
        await withCheckedContinuation { continuation in
            fetchLatestRestingHeartRate { restingHR, error in
                if let error = error {
                    self.logger.error("Failed to fetch resting HR asynchronously: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: restingHR)
                }
            }
        }
    }
  
    /// Async wrapper for calculateIntensityScore.
    public func calculateIntensityScoreAsync(dateInterval: DateInterval, restingHeartRate: Double?) async -> Double? {
        await withCheckedContinuation { continuation in
            calculateIntensityScore(dateInterval: dateInterval, restingHeartRate: restingHeartRate) { score, error in
                if let error = error {
                    self.logger.error("Failed to calculate intensity score asynchronously: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: score)
                }
            }
        }
    }
    
    // MARK: - Time in Heart Rate Zones
    /// Async wrapper for calculateTimeInZones.
    func calculateTimeInZonesAsync(dateInterval: DateInterval, maxHeartRate: Double?) async -> ([Int: Double]?, Int?) {
        await withCheckedContinuation { continuation in
            calculateTimeInZones(dateInterval: dateInterval, maxHeartRate: maxHeartRate) { timeInZones, dominantZone, error in
                if let error = error {
                    self.logger.error("Failed to calculate time in zones asynchronously: \(error.localizedDescription)")
                    continuation.resume(returning: (nil, nil))
                } else {
                    continuation.resume(returning: (timeInZones, dominantZone))
                }
            }
        }
    }
    
    /// Fetches max heart rate asynchronously.
    func fetchMaxHeartRateAsync() async throws -> Double? {
        let (_, _, maxHR) = try await fetchHealthMetrics()
        return maxHR
    }
    
    // MARK: SAVE WORKOUT
    func saveWorkout(_ workout: Workout, history: History, samples: [HKSample]) async throws -> Bool {
        guard isWriteAuthorized else {
            logger.error("Cannot save workout: HealthKit authorization denied.")
            throw AppError.healthKitNotAuthorized
        }
        
        guard history.lastSessionDuration > 0 else {
            logger.error("Invalid workout duration: \(history.lastSessionDuration)")
            throw HealthKitError.invalidWorkoutDuration
        }
        
        let config = HKWorkoutConfiguration()
        // Dynamic activity type from workout category (improved integration)
        config.activityType = workout.category?.categoryColor.hkActivityType ?? .other
        config.locationType = .indoor  // Default; adjust if needed
        
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: config,
            device: .local()
        )
        
        try await builder.beginCollection(at: history.date)
        try await builder.addSamples(samples)
        
        let metadata: [String: Any] = ["workoutTitle": workout.title]
        try await builder.addMetadata(metadata)
        
        try await endCollectionAsync(builder: builder, endDate: history.date.addingTimeInterval(history.lastSessionDuration * 60))
        
        let _ = try await builder.finishWorkout()
        logger.info("Workout saved successfully with title: \(workout.title)")
        return true
    }
    
    private func endCollectionAsync(builder: HKWorkoutBuilder, endDate: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: endDate) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    // MARK: - Fetch Workouts
    /// Fetches workouts from HealthKit.
    /// - Returns: Array of HKWorkout.
    /// - Throws: HealthKitError or query errors.
    func fetchWorkoutsFromHealthKit() async throws -> [HKWorkout] {
        guard isReadAuthorized else {
            throw HealthKitError.healthDataUnavailable
        }
        
        let predicate = HKQuery.predicateForWorkouts(with: .greaterThanOrEqualTo, duration: 0)  // All workouts
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }
}


