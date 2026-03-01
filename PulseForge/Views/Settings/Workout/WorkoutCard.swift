//
//  WorkoutCard.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Workout summary card used in lists and navigation.
//  - Displays category colour stripe, ghosted category name, title, exercise count,
//    rounds (if enabled), and last session time.
//  - Full VoiceOver accessibility with combined elements, labels, hints, and button traits.
//  - Dynamic type support and high contrast compatibility.
//  - No sensitive data; relies on SwiftData for local persistence.
//

import SwiftUI
import SwiftData

/// A high-performance summary card for a single ``Workout``.
///
/// ## Visual design
/// The card uses a dark-surface, sport-equipment aesthetic:
/// - A full-height category colour stripe on the leading edge acts as an
///   immediate visual classifier, similar to colour-coded training zones.
/// - The category name is letterpress-ghosted across the card background
///   so it reads as atmosphere rather than noise.
/// - A monospaced stat row at the bottom mirrors sports-watch data displays.
///
/// The card navigates to ``WorkoutDetailView`` on tap.
struct WorkoutCard: View {

    // MARK: - Properties

    let workout: Workout

    @Environment(ErrorManager.self) private var errorManager

    // Resolved once to avoid repeated optional chaining in subviews.
    private var accent: Color {
        workout.category?.categoryColor.color ?? Color(.systemGray3)
    }

    private var exerciseCount: Int {
        workout.exercises?.count ?? 0
    }

    // MARK: - Body

    var body: some View {
        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
            cardSurface
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double-tap to open workout details")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Card Surface

    private var cardSurface: some View {
        HStack(spacing: 0) {
            // ── Category stripe ───────────────────────────────────────────────
            // Full-height accent bar — the primary visual classifier.
            accent
                .frame(width: 7)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius:     14,
                        bottomLeadingRadius:  14,
                        bottomTrailingRadius:  0,
                        topTrailingRadius:     0
                    )
                )

            // ── Card body ─────────────────────────────────────────────────────
            ZStack(alignment: .trailing) {
                ghostedCategoryLabel
                cardContent
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius:     0,
                    bottomLeadingRadius:  0,
                    bottomTrailingRadius: 14,
                    topTrailingRadius:    14
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        .shadow(color: accent.opacity(0.10), radius: 20, x: 0, y: 8)
    }

    // MARK: - Ghosted Category Name

    /// Large, watermark-style category name printed across the trailing half
    /// of the card. Purely decorative — hidden from accessibility tree.
    private var ghostedCategoryLabel: some View {
        Text((workout.category?.categoryName ?? "").uppercased())
            .font(.system(size: 48, weight: .black, design: .rounded))
            .foregroundStyle(accent.opacity(0.09))
            .lineLimit(1)
            .allowsTightening(true)
            .padding(.trailing, -4)
            .accessibilityHidden(true)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            Divider()
                .overlay(accent.opacity(0.25))
            statsRow
        }
    }

    // MARK: - Title Row

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // Category icon inside a tinted capsule badge.
            categoryBadge

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.title)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let categoryName = workout.category?.categoryName {
                    Text(categoryName.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                        .tracking(1.5)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Category Badge

    /// Tinted circular icon representing the workout category.
    private var categoryBadge: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.15))
                .frame(width: 46, height: 46)

            Image(systemName: workout.category?.symbol ?? "figure.run")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(accent)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Stats Row

    /// Monospaced data strip mirroring sports-watch readouts.
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(exerciseCount)",
                label: exerciseCount == 1 ? "EXERCISE" : "EXERCISES",
                icon: "list.bullet"
            )

            if workout.roundsEnabled && workout.roundsQuantity > 1 {
                statDivider
                statCell(
                    value: "\(workout.roundsQuantity)",
                    label: "ROUNDS",
                    icon: "repeat"
                )
            }

            statDivider
            statCell(
                value: lastSessionTime,
                label: "LAST TIME",
                icon: "stopwatch"
            )

            Spacer(minLength: 0)

            // Personal best indicator — shown when a fastest time is recorded.
            if let fastest = workout.fastestTime, fastest > 0 {
                personalBestBadge
            }
        }
    }

    private func statCell(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(accent.opacity(0.8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)

                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
            }
        }
        .padding(.trailing, 16)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.5))
            .frame(width: 1, height: 24)
            .padding(.trailing, 14)
            .accessibilityHidden(true)
    }

    /// Small star badge shown when a personal best exists for this workout.
    private var personalBestBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .bold))
            Text("PB")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(Color(.systemBackground))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.yellow)
        )
        .accessibilityLabel("Personal best recorded")
    }

    // MARK: - Helpers

    /// Formats the most recent session duration as `m:ss`.
    ///
    /// Checks `workout.lastSessionDuration` first (written on session save),
    /// then falls back to the most recent `History` entry's duration so the
    /// card shows data even if `lastSessionDuration` wasn't flushed yet.
    /// Returns `"NEW"` when no session has ever been completed.
    private var lastSessionTime: String {
        // Primary source — written directly on the Workout model after each session.
        let duration = workout.lastSessionDuration > 0
            ? workout.lastSessionDuration
            : (workout.history ?? [])
                .sorted { $0.date > $1.date }
                .first(where: { $0.lastSessionDuration > 0 })
                .map(\.lastSessionDuration)

        guard let d = duration, d > 0 else { return "NEW" }

        let totalSeconds = Int((d * 60).rounded())
        let minutes      = totalSeconds / 60
        let seconds      = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Full VoiceOver description assembled from all visible data.
    private var accessibilityDescription: String {
        var parts = ["Workout: \(workout.title)"]

        if let category = workout.category?.categoryName {
            parts.append("Category: \(category)")
        }

        parts.append("\(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises")")

        if workout.roundsEnabled && workout.roundsQuantity > 1 {
            parts.append("\(workout.roundsQuantity) rounds")
        }

        if workout.lastSessionDuration > 0 {
            parts.append("Last session: \(lastSessionTime)")
        }

        if let fastest = workout.fastestTime, fastest > 0 {
            parts.append("Personal best recorded")
        }

        return parts.joined(separator: ", ")
    }
}
