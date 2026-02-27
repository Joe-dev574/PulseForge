//
//  StatsSectionView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/20/26.
//
//  Apple App Store Compliance (required for review):
//  - All calculations are delegated to MetricsManager (single source of truth).
//  - Premium metrics (intensity, dominant zone, etc.) strictly gated behind subscription.
//  - HealthKit sync performed only when authorised and only for on-device storage.
//  - Full VoiceOver accessibility, Dynamic Type, and Reduce Motion support.
//  - No data leaves the device except private iCloud (premium only).
//

import SwiftUI
import SwiftData
import OSLog

// MARK: - StatsSectionView

/// Displays workout statistics sourced from ``MetricsManager``.
///
/// Free tier: session count, total time, average duration.
/// Premium tier: average intensity score and dominant HR zone, each shown
/// with a filled gauge bar so the numbers carry immediate visual weight.
///
/// The section header uses the app's theme colour and a monospaced caps
/// treatment consistent with `WorkoutCard`'s stat strip aesthetic.
struct StatsSectionView: View {

    // MARK: Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(MetricsManager.self) private var metricsManager
    @Environment(PurchaseManager.self) private var purchaseManager

    // MARK: Input

    let themeColor: Color

    // MARK: Queries & State

    @Query private var workouts: [Workout]

    @State private var metrics: WorkoutMetrics?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tnt.PulseForge",
        category: "StatsSectionView"
    )

    // MARK: - Body

    var body: some View {
        Section {
            sectionBody
        } header: {
            sectionHeader
        }
        .task { await loadStatistics() }
        .onChange(of: workouts)                        { _, _ in Task { await loadStatistics() } }
        .onChange(of: healthKitManager.isReadAuthorized) { _, _ in Task { await loadStatistics() } }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            // Accent pip — mirrors the WorkoutCard stripe motif.
            Capsule()
                .fill(themeColor)
                .frame(width: 3, height: 14)
                .accessibilityHidden(true)

            Text("STATISTICS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(themeColor)
                .tracking(2)

            Spacer()
        }
        .padding(.top, 4)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Statistics Section")
    }

    // MARK: - Section Body

    @ViewBuilder
    private var sectionBody: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(error)
        } else if workouts.isEmpty && !healthKitManager.isReadAuthorized {
            emptyStateView
        } else {
            freeMetricsRows
            Divider().padding(.vertical, 4)
            premiumBlock
        }
    }

    // MARK: - Loading / Error / Empty

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(themeColor)
            Text("Loading stats…")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 16)
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28))
                .foregroundStyle(themeColor.opacity(0.5))
                .accessibilityHidden(true)
            Text("No workout data yet.")
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .foregroundStyle(.primary)
            Text("Authorise HealthKit or log a workout to see statistics.")
                .font(.system(.caption, design: .serif))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Free Metrics

    private var freeMetricsRows: some View {
        Group {
            StatDataRow(
                icon: "figure.strengthtraining.traditional",
                title: "TOTAL SESSIONS",
                value: "\(metrics?.totalWorkouts ?? 0)",
                accent: themeColor
            )
            StatDataRow(
                icon: "clock",
                title: "TOTAL TIME",
                value: formattedDuration(metrics?.totalWorkoutTime ?? 0),
                accent: themeColor
            )
            StatDataRow(
                icon: "waveform.path.ecg",
                title: "AVG DURATION",
                value: formattedDuration(metrics?.averageSessionDuration ?? 0),
                accent: themeColor
            )
        }
    }

    // MARK: - Premium Block

    @ViewBuilder
    private var premiumBlock: some View {
        if purchaseManager.isSubscribed {
            if let intensity = metrics?.intensityScore {
                GaugeStatRow(
                    icon: "bolt.fill",
                    title: "AVG INTENSITY",
                    value: intensity,
                    maxValue: 100,
                    displayText: String(format: "%.0f / 100", intensity),
                    accent: themeColor
                )
            }
            if let zone = metrics?.dominantZone {
                GaugeStatRow(
                    icon: "heart.fill",
                    title: "DOMINANT ZONE",
                    value: Double(zone),
                    maxValue: 5,
                    displayText: "Zone \(zone) — \(hrZoneLabel(zone))",
                    accent: hrZoneColor(zone)
                )
            }
        } else {
            PremiumUpgradeRow(themeColor: themeColor)
        }
    }

    // MARK: - Helpers

    /// Formats a duration in minutes to a concise string.
    private func formattedDuration(_ minutes: Double) -> String {
        guard minutes > 0 else { return "—" }
        if minutes >= 60 {
            let h = Int(minutes) / 60
            let m = Int(minutes) % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return String(format: "%.0f min", minutes)
    }

    private func hrZoneLabel(_ zone: Int) -> String {
        switch zone {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "Unknown"
        }
    }

    private func hrZoneColor(_ zone: Int) -> Color {
        switch zone {
        case 1: return .teal
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }

    // MARK: - Data Loading

    private func loadStatistics() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            if healthKitManager.isReadAuthorized {
                _ = try await healthKitManager.fetchWorkoutsFromHealthKit()
            }
            metrics = await metricsManager.fetchMetrics()
        } catch {
            logger.error("Failed to load statistics: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Unable to load statistics. Please try again."
        }

        isLoading = false
    }
}

// MARK: - StatDataRow

/// A single labelled data row matching the WorkoutCard monospaced stat aesthetic.
private struct StatDataRow: View {
    let icon:   String
    let title:  String
    let value:  String
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent.opacity(0.85))
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - GaugeStatRow

/// A premium stat row with a filled accent bar that communicates the value
/// proportionally — no numbers needed at a glance.
private struct GaugeStatRow: View {
    let icon:        String
    let title:       String
    let value:       Double
    let maxValue:    Double
    let displayText: String
    let accent:      Color

    private var fraction: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accent.opacity(0.85))
                    .frame(width: 20)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)

                Spacer()

                Text(displayText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            // Gauge bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(accent.opacity(0.12))
                        .frame(height: 5)
                    Capsule()
                        .fill(accent)
                        .frame(width: geo.size.width * fraction, height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(displayText)")
    }
}

// MARK: - PremiumUpgradeRow

/// A compact, tasteful upsell that fits within the form without breaking visual rhythm.
private struct PremiumUpgradeRow: View {
    let themeColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 13))
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("PREMIUM METRICS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Text("Intensity score, HR zone & Progress Pulse")
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("UNLOCK")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(.systemBackground))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(themeColor))
                .tracking(1)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Unlock premium for intensity score, HR zone, and Progress Pulse metrics")
        .accessibilityAddTraits(.isButton)
    }
}
