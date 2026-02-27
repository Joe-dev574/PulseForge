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

import SwiftData
import OSLog
import Observation

// MARK: - Supporting Types

/// Aggregated free-tier metrics derived from local SwiftData history.
///
/// Structured as a named type rather than an anonymous tuple so that
/// call sites are self-documenting and the type can be unit-tested directly.
private struct FreeMetrics {
    let totalWorkouts:  Int
    let avgDuration:    Double          // minutes
    let totalTime:      Double          // minutes
    let lastDuration:   Double          // minutes
    let workoutsPerWeek: Int
    let fastestTime:    Double          // minutes; 0 when unavailable
    let currentStreak:  Int             // calendar days
    let longestStreak:  Int             // calendar days
    let splits:         [SplitTime]
}

/// Aggregated premium metrics derived from HealthKit.
///
/// All fields are optional because HealthKit authorisation may be absent,
/// the user may not be subscribed, or the relevant HK samples may not exist.
private struct PremiumMetrics {
    let intensityScore:    Double?
    let progressPulseScore: Double?
    let dominantZone:      Int?
    let timeInZones:       [Int: Double]?
    let restingHeartRate:  Double?
    let maxHeartRate:      Double?
    let estimatedDistance: Double?

    /// Fully-nil default returned when the user is not subscribed or
    /// a `history`/`workout` context is unavailable.
    static let empty = PremiumMetrics(
        intensityScore:     nil,
        progressPulseScore: nil,
        dominantZone:       nil,
        timeInZones:        nil,
        restingHeartRate:   nil,
        maxHeartRate:       nil,
        estimatedDistance:  nil
    )
}

// MARK: - MetricsManager

/// Coordinates all workout metric calculations for PulseForge.
///
/// `MetricsManager` is the single source of truth for both free and premium
/// performance data. It is designed to be injected via SwiftUI's `@Environment`
/// rather than accessed through `MetricsManager.shared` directly in views,
/// which improves testability and preview support.
///
/// ## Usage
/// ```swift
/// // In App / Scene root:
/// .environment(MetricsManager.shared)
///
/// // In a view:
/// @Environment(MetricsManager.self) private var metricsManager
/// ```
///
/// ## Threading
/// The class is `@MainActor` and `@Observable`. All `async` work is dispatched
/// internally; callers should use `Task { }` or `.task { }` modifiers.
///
/// ## Subscription gating
/// Premium HealthKit metrics are only calculated when
/// `PurchaseManager.isSubscribed` is `true`. Free-tier metrics are always
/// available and derived entirely from on-device SwiftData records.
///
/// - Important: All data remains on-device or in the user's private iCloud
///   container (end-to-end encrypted). No health data is transmitted externally.
@MainActor @Observable
final class MetricsManager {

    // MARK: Dependencies

    private let healthKitManager: HealthKitManager
    private let purchaseManager:  PurchaseManager
    private let modelContext:     ModelContext
    private let errorManager:     ErrorManager

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tnt.PulseForge",
        category: "MetricsManager"
    )

    // MARK: Singleton

    /// Process-wide shared instance wired to production dependencies.
    ///
    /// Prefer injecting this via `@Environment` rather than referencing
    /// `MetricsManager.shared` inside view bodies, so that previews and
    /// unit tests can substitute a custom instance.
    static let shared = MetricsManager(
        healthKitManager: .shared,
        purchaseManager:  .shared,
        modelContext:     PulseForgeContainer.container.mainContext,
        errorManager:     .shared
    )

    // MARK: Initialiser

    /// Creates a `MetricsManager` with explicit dependency injection.
    ///
    /// - Parameters:
    ///   - healthKitManager: Abstracts all HealthKit queries.
    ///   - purchaseManager:  Provides the current subscription state.
    ///   - modelContext:     SwiftData context used for history queries.
    ///   - errorManager:     Centralised error presentation layer.
    init(
        healthKitManager: HealthKitManager,
        purchaseManager:  PurchaseManager,
        modelContext:     ModelContext,
        errorManager:     ErrorManager
    ) {
        self.healthKitManager = healthKitManager
        self.purchaseManager  = purchaseManager
        self.modelContext     = modelContext
        self.errorManager     = errorManager
    }

    // MARK: - Public API

    /// Fetches and assembles a complete ``WorkoutMetrics`` snapshot.
    ///
    /// Free metrics are always calculated from SwiftData. Premium metrics
    /// (HealthKit-derived) are only calculated when the user is subscribed.
    /// On any failure the method logs the error, presents a user-facing alert
    /// via `ErrorManager`, and returns a safe default ``WorkoutMetrics``.
    ///
    /// - Parameters:
    ///   - workout: Scope history queries to this workout; `nil` fetches all.
    ///   - history: The specific session used for split times and HealthKit
    ///              window alignment. Required for premium metrics.
    /// - Returns: A fully populated (or safely defaulted) ``WorkoutMetrics``.
    func fetchMetrics(
        for workout: Workout? = nil,
        history: History? = nil
    ) async -> WorkoutMetrics {
        do {
            let free    = try await calculateFreeMetrics(for: workout, history: history)
            let premium = purchaseManager.isSubscribed
                ? try await calculatePremiumMetrics(for: workout, history: history)
                : .empty

            return WorkoutMetrics(
                totalWorkouts:          free.totalWorkouts,
                averageSessionDuration: free.avgDuration,
                totalWorkoutTime:       free.totalTime,
                lastSessionDuration:    free.lastDuration,
                workoutsPerWeek:        free.workoutsPerWeek,
                fastestTime:            free.fastestTime,
                currentStreak:          free.currentStreak,
                longestStreak:          free.longestStreak,
                exerciseSplits:         free.splits,
                intensityScore:         premium.intensityScore,
                progressPulseScore:     premium.progressPulseScore,
                dominantZone:           premium.dominantZone,
                timeInZones:            premium.timeInZones,
                restingHeartRate:       premium.restingHeartRate,
                maxHeartRate:           premium.maxHeartRate,
                estimatedDistance:      premium.estimatedDistance
            )
        } catch {
            logger.error("fetchMetrics failed: \(error.localizedDescription, privacy: .public)")
            errorManager.present(
                title: "Metrics Error",
                message: "Failed to load metrics. Please try again."
            )
            return WorkoutMetrics()
        }
    }
}

// MARK: - Free Metrics

private extension MetricsManager {

    /// Computes all metrics available without a subscription.
    ///
    /// Data is sourced entirely from SwiftData ``History`` records, so no
    /// HealthKit authorisation is required.
    ///
    /// - Parameters:
    ///   - workout: Scope; `nil` aggregates across all workouts.
    ///   - history: Session whose split times are surfaced directly.
    func calculateFreeMetrics(
        for workout: Workout?,
        history: History?
    ) async throws -> FreeMetrics {

        // All history records for this workout, sorted newest → oldest.
        let histories = try fetchHistories(for: workout)

        let totalWorkouts = histories.count
        let totalTime     = histories.reduce(0.0) { $0 + $1.lastSessionDuration }
        let avgDuration   = totalWorkouts > 0 ? totalTime / Double(totalWorkouts) : 0.0

        // `fetchHistories` sorts descending, so `.first` is the most recent session.
        let lastDuration  = histories.first?.lastSessionDuration ?? 0.0

        let workoutsPerWeek: Int = workout.map {
            MetricsCalculator.fetchWorkoutsPerWeek(workout: $0, modelContext: modelContext)
        } ?? 0

        // fastestTime is maintained by Workout.updateFastestTime(); use it directly
        // rather than recomputing here to avoid duplicating that logic.
        let fastestTime = workout?.fastestTime ?? 0.0

        // Streak calculation works on calendar days; extract normalised dates.
        let sessionDays = histories.map { Calendar.current.startOfDay(for: $0.date) }
        let (currentStreak, longestStreak) = calculateStreaks(from: sessionDays)

        // SplitTimes are session-specific and only relevant when a History is provided.
        let splits = history?.splitTimes ?? []

        logger.info(
            "Free metrics calculated: \(totalWorkouts, privacy: .public) sessions, streak \(currentStreak, privacy: .public)/\(longestStreak, privacy: .public)"
        )

        return FreeMetrics(
            totalWorkouts:   totalWorkouts,
            avgDuration:     avgDuration,
            totalTime:       totalTime,
            lastDuration:    lastDuration,
            workoutsPerWeek: workoutsPerWeek,
            fastestTime:     fastestTime,
            currentStreak:   currentStreak,
            longestStreak:   longestStreak,
            splits:          splits
        )
    }
}

// MARK: - Premium Metrics

private extension MetricsManager {

    /// Computes HealthKit-derived metrics for subscribed users.
    ///
    /// Returns ``PremiumMetrics/empty`` immediately when either `history` or
    /// `workout` is `nil`, since a concrete session window is required to
    /// correctly scope HealthKit queries.
    ///
    /// - Parameters:
    ///   - workout: The workout whose category drives distance estimation.
    ///   - history: The completed session that defines the HealthKit time window.
    func calculatePremiumMetrics(
        for workout: Workout?,
        history: History?
    ) async throws -> PremiumMetrics {

        guard let history, let workout else {
            logger.debug("Premium metrics skipped: no history/workout context.")
            return .empty
        }

        let startDate = history.date
        let endDate   = Date(timeInterval: history.lastSessionDuration * 60, since: startDate)

        // `calculateAdvancedMetrics` writes back to the History model and returns
        // the updated object with intensityScore, progressPulseScore, and dominantZone set.
        let updatedHistory = try await MetricsCalculator.calculateAdvancedMetrics(
            history:               history,
            workout:               workout,
            startDate:             startDate,
            endDate:               endDate,
            modelContext:          modelContext,
            authenticationManager: AuthenticationManager.shared,
            healthKitManager:      healthKitManager
        )

        // Fetch resting and max HR concurrently; both are independent HealthKit queries.
        async let restingHR = healthKitManager.fetchLatestRestingHeartRateAsync()
        async let maxHR     = healthKitManager.fetchMaxHeartRateAsync()

        let (resting, max) = try await (restingHR, maxHR)

        let distance = healthKitManager.estimateDistance(
            for: workout.category?.categoryColor ?? .STRENGTH,
            durationMinutes: history.lastSessionDuration
        )

        logger.info(
            "Premium metrics calculated: intensity=\(updatedHistory.intensityScore ?? -1, privacy: .public), zone=\(updatedHistory.dominantZone ?? -1, privacy: .public)"
        )

        return PremiumMetrics(
            intensityScore:     updatedHistory.intensityScore,
            progressPulseScore: updatedHistory.progressPulseScore,
            dominantZone:       updatedHistory.dominantZone,
            timeInZones:        nil,           // Reserved: populate when zone-split HK query is implemented
            restingHeartRate:   resting,
            maxHeartRate:       max,
            estimatedDistance:  distance
        )
    }
}

// MARK: - SwiftData Queries

private extension MetricsManager {

    /// Fetches ``History`` records, optionally scoped to a specific ``Workout``.
    ///
    /// Results are sorted descending by date so the first element is always
    /// the most recent session — consistent with the expectation in
    /// ``calculateFreeMetrics``.
    ///
    /// - Parameter workout: When non-nil, only sessions belonging to this
    ///   workout are returned.
    func fetchHistories(for workout: Workout?) throws -> [History] {
        var descriptor = FetchDescriptor<History>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        if let workout {
            let id = workout.persistentModelID
            descriptor.predicate = #Predicate<History> { history in
                history.workout?.persistentModelID == id
            }
        }

        return try modelContext.fetch(descriptor)
    }
}

// MARK: - Streak Calculation

private extension MetricsManager {

    /// Computes the current and longest streaks from an array of calendar-day dates.
    ///
    /// ## Algorithm
    /// The input must be **normalised** calendar days (i.e. `startOfDay` values)
    /// and sorted **descending** (newest first). Duplicates — multiple sessions
    /// on the same day — are collapsed before counting so they contribute only
    /// once to the streak.
    ///
    /// A streak increments when two consecutive unique days in the sorted list
    /// are exactly one calendar day apart. Any gap larger than one day resets
    /// the current counter.
    ///
    /// - Parameter days: Normalised, descending calendar-day `Date` values.
    /// - Returns: A tuple of `(current, longest)` streak lengths in days.
    func calculateStreaks(from days: [Date]) -> (current: Int, longest: Int) {
        // Collapse multiple sessions per day into unique days, preserving sort order.
        let uniqueDays = Array(
            NSOrderedSet(array: days).array as? [Date] ?? []
        )

        guard !uniqueDays.isEmpty else { return (0, 0) }

        var current = 1
        var longest = 1

        let calendar = Calendar.current

        for i in 1..<uniqueDays.count {
            // uniqueDays is descending: uniqueDays[i] is one step further in the past.
            // A streak continues when the gap between adjacent unique days is exactly 1 day.
            let daysBetween = calendar.dateComponents(
                [.day],
                from: uniqueDays[i],
                to: uniqueDays[i - 1]
            ).day ?? 0

            if daysBetween == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                // Gap detected — reset current streak.
                // Note: longest is NOT reset; it tracks the all-time best.
                current = 1
            }
        }

        // Edge case: if all sessions were on the same day uniqueDays has count == 1,
        // both current and longest are correctly 1.
        return (current, longest)
    }
}
