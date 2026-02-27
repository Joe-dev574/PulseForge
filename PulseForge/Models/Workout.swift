//
//  Workout.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//
//  Apple App Store Compliance:
//  - All data stored locally and synced via private iCloud (end-to-end encrypted).
//  - No personal health data transmitted to external servers.
//  - HealthKit usage is internal only; no server-side transmission.
//  - Conforms to SwiftData @Model for persistence and CloudKit compatibility.
//

import SwiftData
import OSLog

// MARK: - Workout

/// A persistent model representing a reusable workout routine.
///
/// `Workout` is the central entity in PulseForge's data model. It stores the workout's
/// configuration (title, category, exercises, rounds), tracks performance over time via
/// its `History` relationship, and maintains derived metrics such as fastest time and
/// a generated performance summary.
///
/// ## Relationships
/// - ``category``: Optional ``Category`` grouping (nullify on delete).
/// - ``exercises``: Ordered ``Exercise`` array (cascade delete).
/// - ``history``: Completed session records (cascade delete).
///
/// ## Threading
/// Mutations that touch `ModelContext` are annotated `@MainActor`.
/// Read-only computed properties are safe to access from any thread.
///
/// - Important: All data is stored locally and synced via private iCloud
///   (end-to-end encrypted); no server transmission occurs.
/// - Privacy: Contains user-created workout configuration. History entries
///   may contain health-adjacent data; handle per your privacy policy.
@Model
final class Workout {

    // MARK: Stored Properties

    /// Stable unique identifier. Generated once at creation and never mutated.
    var id: UUID = UUID()

    /// Human-readable title (e.g., "Upper Body A", "5K Tempo Run").
    /// Must be non-empty; enforced in ``init``.
    var title: String = "New Workout"

    /// Duration of the most recently completed session, in minutes.
    /// Zero until the first session is finished.
    var lastSessionDuration: Double = 0.0

    /// Timestamp when this workout was first created.
    var dateCreated: Date = Date()

    /// Timestamp of the most recent completed session, if any.
    var dateCompleted: Date?

    /// Optional category used for colour-coding and organisation.
    /// Nullified (not deleted) when the workout is removed.
    @Relationship(deleteRule: .nullify)
    var category: Category?

    /// Whether rounds (circuit) mode is active for this workout.
    var roundsEnabled: Bool = false

    /// Number of rounds when ``roundsEnabled`` is `true`. Clamped to ≥ 1.
    var roundsQuantity: Int = 1

    /// Personal-best session duration in minutes, derived from ``history``.
    /// `nil` until at least one valid session is recorded.
    var fastestTime: Double?

    /// Structured performance summary built from ``history`` metrics.
    /// Each line is a discrete stat; `nil` when no history exists.
    /// Stored as a newline-delimited string for lightweight persistence.
    var generatedSummary: String?

    /// Ordered collection of exercises belonging to this workout.
    /// Cascade-deleted when the workout is removed.
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise]? = []

    /// All completed session records for this workout.
    /// Cascade-deleted when the workout is removed.
    @Relationship(deleteRule: .cascade, inverse: \History.workout)
    var history: [History]? = []

    // MARK: Transient

    /// OSLog logger scoped to the Workout category. Not persisted.
    @Transient
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tnt.PulseForge",
        category: "Workout"
    )

    // MARK: - Initialiser

    /// Creates a new `Workout` with the supplied configuration.
    ///
    /// - Parameters:
    ///   - title: Display name. Must be non-empty.
    ///   - exercises: Pre-populated exercise list (defaults to empty).
    ///   - lastSessionDuration: Seed duration in minutes (defaults to 0).
    ///   - dateCreated: Creation timestamp (defaults to now).
    ///   - dateCompleted: Last completion timestamp (defaults to `nil`).
    ///   - category: Optional grouping ``Category``.
    ///   - roundsEnabled: Activates circuit-rounds mode (defaults to `false`).
    ///   - roundsQuantity: Round count; ignored when `roundsEnabled` is `false` (defaults to 1).
    ///
    /// - Precondition: `title` must not be empty. Violation triggers a `fatalError`
    ///   to surface programming errors early in development; consider replacing
    ///   with a `throw`-based initialiser if the title source is user-controlled.
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
        // Programmer error: callers must never supply an empty title.
        precondition(!title.trimmingCharacters(in: .whitespaces).isEmpty,
                     "Workout title must not be empty or whitespace-only.")
        self.title               = title.trimmingCharacters(in: .whitespaces)
        self.exercises           = exercises
        self.lastSessionDuration = lastSessionDuration
        self.dateCreated         = dateCreated
        self.dateCompleted       = dateCompleted
        self.category            = category
        self.roundsEnabled       = roundsEnabled
        // Guarantee the invariant: roundsQuantity is always ≥ 1.
        self.roundsQuantity      = max(1, roundsQuantity)
    }
}

// MARK: - Exercise Accessors

extension Workout {

    /// Exercises sorted ascending by their display order.
    var sortedExercises: [Exercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    /// Exercises expanded by ``roundsQuantity`` when rounds mode is active.
    ///
    /// Example: 3 exercises × 2 rounds → 6 items, preserving sort order within each round.
    var effectiveExercises: [Exercise] {
        guard roundsEnabled, roundsQuantity > 1 else { return sortedExercises }
        // flatMap over a repeated sequence is O(n·r) but n is small for workouts.
        return (0..<roundsQuantity).flatMap { _ in sortedExercises }
    }
}

// MARK: - Performance Metrics

extension Workout {

    /// Formatted personal-best duration string (e.g., "32m 10s", "1h 4m 0s").
    /// Returns `"N/A"` when no valid sessions have been recorded.
    var formattedFastestTime: String {
        fastestTime.map { formatDuration($0 * 60) } ?? "N/A"
    }

    /// Recalculates ``fastestTime`` from the current ``history`` array.
    ///
    /// Call this after persisting a new ``History`` entry so that the personal
    /// best remains consistent with stored data. This method does **not** save
    /// the `ModelContext`; callers are responsible for persisting the change.
    func updateFastestTime() {
        logger.info("Recalculating fastest time for '\(self.title, privacy: .public)'")

        let validDurations = (history ?? [])
            .map(\.lastSessionDuration)
            .filter { $0 > 0 }

        guard !validDurations.isEmpty else {
            fastestTime = nil
            logger.info("No valid sessions; fastest time cleared.")
            return
        }

        fastestTime = validDurations.min()
        logger.info("Fastest time updated to \(self.fastestTime ?? 0, privacy: .public) min")
    }
}

// MARK: - Generated Summary

extension Workout {

    /// Rebuilds ``generatedSummary`` from all available ``History`` metrics and
    /// persists the change via `context`.
    ///
    /// The summary is stored as a newline-delimited string so that the view layer
    /// can split it into individual labelled rows without parsing overhead.
    ///
    /// ## Metrics included
    /// | Metric | Source |
    /// |---|---|
    /// | Session count, avg & best duration | ``History/lastSessionDuration`` |
    /// | Performance trend | First-half vs second-half avg duration comparison |
    /// | Active streak | Consecutive calendar days with at least one session |
    /// | Avg intensity | ``History/intensityScore`` |
    /// | Progress Pulse avg | ``History/progressPulseScore`` |
    /// | Dominant HR zone | ``History/dominantZone`` frequency |
    /// | Notes habit | Count of sessions with non-empty ``History/notes`` |
    ///
    /// - Parameter context: The `ModelContext` used to persist changes.
    @MainActor
    func updateGeneratedSummary(in context: ModelContext) {
        logger.info("Rebuilding generatedSummary for '\(self.title, privacy: .public)'")

        let sessions = history ?? []

        guard !sessions.isEmpty else {
            generatedSummary = nil
            logger.info("No history; generatedSummary cleared.")
            return
        }

        // ── Core duration metrics ─────────────────────────────────────────────

        let validDurations = sessions
            .map(\.lastSessionDuration)
            .filter { $0 > 0 }

        let avgDurationMin: Double = validDurations.isEmpty
            ? 0
            : validDurations.reduce(0, +) / Double(validDurations.count)

        let avgFormatted     = formatDuration(avgDurationMin * 60)
        let fastestFormatted = fastestTime.map { formatDuration($0 * 60) } ?? "N/A"
        let totalSessions    = sessions.count

        // ── Trend: first-half vs second-half average ──────────────────────────
        //
        // Requires ≥ 4 valid-duration sessions to be statistically meaningful.
        // A negative delta means recent sessions are faster (shorter duration).

        let trendLine: String? = {
            guard validDurations.count >= 4 else { return nil }
            let mid           = validDurations.count / 2
            let firstHalfAvg  = validDurations.prefix(mid).reduce(0, +) / Double(mid)
            let secondHalfAvg = validDurations.suffix(mid).reduce(0, +) / Double(mid)
            let delta         = secondHalfAvg - firstHalfAvg          // minutes
            let threshold     = 0.5                                    // ignore < 30s swings

            if delta < -threshold {
                return "⚡️ Trending faster — avg time down \(formatDuration(abs(delta) * 60)) recently"
            } else if delta > threshold {
                return "📈 Sessions running longer — consider pacing or extra recovery"
            } else {
                return "📊 Consistent performance across sessions"
            }
        }()

        // ── Active streak ─────────────────────────────────────────────────────
        //
        // Counts how many consecutive calendar days ending today have ≥ 1 session.

        let streak: Int = {
            let calendar = Calendar.current
            var count    = 0
            var cursor   = calendar.startOfDay(for: .now)

            // Build a Set<Date> of normalised session dates for O(1) lookup.
            let sessionDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })

            while sessionDays.contains(cursor) {
                count += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            }
            return count
        }()

        // ── Optional metric averages ──────────────────────────────────────────

        let avgIntensity: Double? = {
            let scores = sessions.compactMap(\.intensityScore)
            return scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
        }()

        let avgPulse: Double? = {
            let scores = sessions.compactMap(\.progressPulseScore)
            return scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
        }()

        // ── Dominant HR zone ──────────────────────────────────────────────────

        let topZone: Int? = {
            let zones = sessions.compactMap(\.dominantZone)
            guard !zones.isEmpty else { return nil }
            // Dictionary(grouping:) is O(n); fine for typical history sizes.
            return Dictionary(grouping: zones, by: { $0 })
                .max(by: { $0.value.count < $1.value.count })?.key
        }()

        // ── Notes habit ───────────────────────────────────────────────────────

        let notesCount = sessions.filter { !($0.notes?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) }.count

        // ── Assemble summary lines ────────────────────────────────────────────

        var lines: [String] = []

        // Line 0: headline — always present.
        lines.append(
            "Completed \(totalSessions) session\(totalSessions == 1 ? "" : "s") · Avg \(avgFormatted) · Best \(fastestFormatted)"
        )

        if streak > 1 {
            lines.append("🔥 \(streak)-day active streak")
        }

        if let trend = trendLine {
            lines.append(trend)
        }

        if let intensity = avgIntensity {
            lines.append(String(format: "Avg intensity: %.0f / 100", intensity))
        }

        if let pulse = avgPulse {
            lines.append(String(format: "Progress Pulse avg: %.0f / 100", pulse))
        }

        if let zone = topZone {
            lines.append("Most common HR zone: Zone \(zone) — \(hrZoneDescription(zone))")
        }

        if notesCount > 0 {
            lines.append("\(notesCount) session\(notesCount == 1 ? "" : "s") with notes logged")
        }

        generatedSummary = lines.joined(separator: "\n")
        logger.info("generatedSummary updated (\(lines.count, privacy: .public) lines)")

        // ── Persist ───────────────────────────────────────────────────────────

        guard context.hasChanges else { return }

        do {
            try context.save()
            logger.info("ModelContext saved after summary update.")
        } catch {
            logger.error("ModelContext save failed: \(error.localizedDescription, privacy: .public)")
            ErrorManager.shared.present(
                title: "Save Error",
                message: "Failed to save workout summary: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Private Helpers

private extension Workout {

    /// Maps a HealthKit-style heart rate zone number to a descriptive label.
    ///
    /// - Parameter zone: Integer zone (1–5).
    /// - Returns: Human-readable label, or `"Unknown"` for out-of-range values.
    func hrZoneDescription(_ zone: Int) -> String {
        switch zone {
        case 1:  return "Very Light"
        case 2:  return "Light"
        case 3:  return "Moderate"
        case 4:  return "Hard"
        case 5:  return "Maximum"
        default: return "Unknown"
        }
    }

    /// Converts a duration in seconds to a compact human-readable string.
    ///
    /// - Parameter seconds: Non-negative duration in seconds.
    /// - Returns: Formatted string such as `"32s"`, `"4m 12s"`, or `"1h 4m 0s"`.
    ///
    /// - Note: `DateComponentsFormatter` would be cleaner but SwiftData's
    ///   `@Model` context makes it tricky to cache the formatter instance;
    ///   this manual approach avoids repeated allocations across hot loops.
    func formatDuration(_ seconds: Double) -> String {
        let total   = max(0, Int(seconds.rounded()))
        let hours   = total / 3600
        let minutes = (total % 3600) / 60
        let secs    = total % 60

        if hours > 0   { return "\(hours)h \(minutes)m \(secs)s" }
        if minutes > 0 { return "\(minutes)m \(secs)s" }
        return "\(secs)s"
    }
}
