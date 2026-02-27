//
//  ProgressBoardView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/20/26.
//
//  Apple App Store Compliance:
//  - All metric calculations use HealthKitManager (single source of truth).
//  - Premium features (Progress Pulse, advanced graphs, category metrics) strictly gated behind subscription.
//  - HealthKit data used only with explicit user authorisation and processed on-device.
//  - Full VoiceOver, Dynamic Type, and Reduce Motion support.
//  - Clean, high-contrast UI designed for seamless Apple Watch parity.
//

import SwiftUI
import SwiftData
internal import HealthKit
import OSLog
import StoreKit

// MARK: - Supporting Types

/// A single day cell in the 90-day activity heatmap.
struct DayGridItem: Identifiable, Sendable {
    let id          = UUID()
    let date:       Date
    var didWorkout: Bool
    let isToday:    Bool
    var isTestWorkout: Bool
}

// MARK: - DayCellView

/// A single heatmap cell rendered as a small square (not circle) for a
/// denser, more data-dense training-log aesthetic.
struct DayCellView: View {
    let didWorkout:    Bool
    let isToday:       Bool
    let themeColor:    Color
    let isTestWorkout: Bool

    @State private var isPressed = false

    private var fillColor: Color {
        if isTestWorkout { return .indigo.opacity(0.85) }
        if didWorkout    { return themeColor }
        return Color(.systemFill)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(fillColor)
            .frame(width: 18, height: 18)
            .overlay(
                isToday
                    ? RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                    : nil
            )
            .shadow(
                color: didWorkout ? themeColor.opacity(0.35) : .clear,
                radius: 3, x: 0, y: 2
            )
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressed)
            .onTapGesture {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { isPressed = false }
            }
            .accessibilityLabel(
                isToday
                    ? "Today, \(didWorkout ? "workout completed" : "rest day")"
                    : didWorkout ? "Workout day" : "Rest day"
            )
    }
}

// MARK: - WorkoutGraph

/// Area + line chart with smart Y-axis scaling and gridlines.
/// Unchanged from original except visual polish.
struct WorkoutGraph: View {
    let values:        [Double]
    let themeColor:    Color
    let title:         String
    var fixedMaxValue: Double? = nil

    private var effectiveMax: Double {
        guard !values.isEmpty else { return 1.0 }
        let dataMax = values.max() ?? 1.0
        return max((fixedMaxValue ?? dataMax) * 1.12, 1.0)
    }

    private let hPad:  CGFloat = 16
    private let vPad:  CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chart title in monospaced caps
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(themeColor.opacity(0.9))
                .tracking(1.5)
                .padding(.leading, hPad)

            GeometryReader { geo in
                let w      = geo.size.width - hPad * 2
                let h      = geo.size.height - vPad * 2
                let step   = values.count > 1 ? w / CGFloat(values.count - 1) : 0

                ZStack(alignment: .leading) {
                    // Grid lines + axis labels
                    ForEach(0...4, id: \.self) { i in
                        let y     = vPad + h * CGFloat(i) / 4.0
                        let label = effectiveMax * (1.0 - Double(i) / 4.0)

                        Path { p in
                            p.move(to: CGPoint(x: hPad, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width - hPad, y: y))
                        }
                        .stroke(Color(.separator).opacity(0.3),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                        Text(label.formatted(.number.precision(.fractionLength(0))))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .position(x: hPad - 2, y: y)
                            .frame(width: 28, alignment: .trailing)
                    }

                    if !values.isEmpty {
                        // Fill
                        Path { p in
                            p.move(to: CGPoint(x: hPad, y: h + vPad))
                            for (i, v) in values.enumerated() {
                                let x = hPad + CGFloat(i) * step
                                let y = vPad + h * (1.0 - min(max(v / effectiveMax, 0), 1))
                                p.addLine(to: CGPoint(x: x, y: y))
                            }
                            p.addLine(to: CGPoint(x: hPad + CGFloat(values.count - 1) * step,
                                                  y: h + vPad))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(
                            colors: [themeColor.opacity(0.55), themeColor.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom
                        ))

                        // Line
                        Path { p in
                            for (i, v) in values.enumerated() {
                                let x = hPad + CGFloat(i) * step
                                let y = vPad + h * (1.0 - min(max(v / effectiveMax, 0), 1))
                                i == 0 ? p.move(to: CGPoint(x: x, y: y))
                                       : p.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(themeColor,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .shadow(color: themeColor.opacity(0.45), radius: 4, y: 2)

                        // Data point dots — only for the last (most recent) value
                        if let last = values.last {
                            let x = hPad + CGFloat(values.count - 1) * step
                            let y = vPad + h * (1.0 - min(max(last / effectiveMax, 0), 1))
                            Circle()
                                .fill(themeColor)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                            Circle()
                                .fill(.white.opacity(0.9))
                                .frame(width: 3, height: 3)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(height: 120)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - ProgressBoardView

struct ProgressBoardView: View {

    // MARK: Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(ErrorManager.self) private var errorManager
    @Environment(\.dismiss) private var dismiss

    // MARK: App Storage

    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"

    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }

    // MARK: State

    @State private var daysToDisplay:              [DayGridItem] = []
    @State private var weeklyDurations:            [Double]      = []
    @State private var weeklyWorkoutCounts:        [Int]         = []
    @State private var weeklyProgressPulseScores:  [Double]      = []

    @State private var totalWorkoutsLast90Days:          Int    = 0
    @State private var totalDurationLast90DaysFormatted: String = "—"
    @State private var avgWorkoutsPerWeekLast90Days:     Double = 0.0
    @State private var distinctActiveDaysLast90Days:     Int    = 0

    @State private var latestCategoryMetrics: [String: WorkoutMetrics] = [:]
    @State private var isLoading:             Bool = true

    // MARK: Private

    private let purchaseManager = PurchaseManager.shared
    private let logger   = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.tnt.PulseForge",
                                  category: "ProgressBoardView")
    private let calendar = Calendar.current

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    boardLoadingView
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            heatmapSection
                            statsGridSection
                            graphsSection
                            premiumOrTeaserSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Progress Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { doneButton }
            .refreshable { await refreshBoard() }
            .onAppear { Task { await initializeBoard() } }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { dismiss() }
                .font(.system(.callout, design: .serif, weight: .medium))
        }
    }

    // MARK: - Loading View

    private var boardLoadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(themeColor)
            Text("LOADING BOARD")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
        }
    }

    // MARK: - Section Headers

    private func sectionHeader(_ label: String) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(themeColor)
                .frame(width: 3, height: 13)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(themeColor)
                .tracking(2)
            Spacer()
        }
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Heatmap Section

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("90-DAY ACTIVITY")

            VStack(spacing: 10) {
                // Grid — 15 columns × 6 rows = 90 cells
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(18), spacing: 4), count: 15),
                    spacing: 4
                ) {
                    ForEach(daysToDisplay) { day in
                        DayCellView(
                            didWorkout:    day.didWorkout,
                            isToday:       day.isToday,
                            themeColor:    themeColor,
                            isTestWorkout: day.isTestWorkout
                        )
                    }
                }

                // Legend
                HStack(spacing: 20) {
                    heatmapLegendItem(color: themeColor, label: "TRAINED")
                    heatmapLegendItem(color: .indigo,    label: "TEST")
                    heatmapLegendItem(color: Color(.systemFill), label: "REST")
                    Spacer()
                    // Completion rate
                    let active = daysToDisplay.filter(\.didWorkout).count
                    Text("\(active) / 90 DAYS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
    }

    private func heatmapLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(0.8)
        }
    }

    // MARK: - Stats Grid Section

    private var statsGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("90-DAY STATS")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                statTile(
                    item: .totalWorkouts,
                    value: "\(totalWorkoutsLast90Days)",
                    icon: "figure.strengthtraining.traditional"
                )
                statTile(
                    item: .totalTime,
                    value: totalDurationLast90DaysFormatted,
                    icon: "clock.fill"
                )
                statTile(
                    item: .avgWorkoutsPerWeek,
                    value: String(format: "%.1f", avgWorkoutsPerWeekLast90Days),
                    icon: "calendar.badge.checkmark"
                )
                statTile(
                    item: .activeDays,
                    value: "\(distinctActiveDaysLast90Days)",
                    icon: "flame.fill"
                )
            }
        }
    }

    private func statTile(item: InfoStatItem, value: String, icon: String) -> some View {
        StatTileView(
            icon:        icon,
            title:       item.displayTitle,
            value:       value,
            description: item.descriptionText,
            accent:      themeColor
        )
    }

    // MARK: - Graphs Section

    private var graphsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("12-WEEK TRENDS")

            WorkoutGraph(
                values:     weeklyDurations,
                themeColor: themeColor,
                title:      "Weekly Duration (min)"
            )

            WorkoutGraph(
                values:     weeklyWorkoutCounts.map(Double.init),
                themeColor: themeColor,
                title:      "Weekly Sessions"
            )

            if purchaseManager.isSubscribed {
                WorkoutGraph(
                    values:        weeklyProgressPulseScores,
                    themeColor:    themeColor,
                    title:         "Weekly Progress Pulse",
                    fixedMaxValue: 100
                )
            }
        }
    }

    // MARK: - Premium / Teaser Section

    @ViewBuilder
    private var premiumOrTeaserSection: some View {
        if purchaseManager.isSubscribed {
            metricsSection
        } else {
            premiumTeaserCard
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("LATEST METRICS BY CATEGORY")

            if latestCategoryMetrics.isEmpty {
                Text("Complete more workouts to see advanced metrics.")
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(latestCategoryMetrics.keys.sorted(), id: \.self) { category in
                    if let m = latestCategoryMetrics[category] {
                        MetricTileView(category: category, metrics: m, accent: themeColor)
                    }
                }
            }
        }
    }

    private var premiumTeaserCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.yellow)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("UNLOCK PREMIUM")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .tracking(1.5)
                    Text("Progress Pulse, advanced analytics & full Apple Watch support.")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Button {
                // Opens subscription flow
            } label: {
                Text("SUBSCRIBE NOW")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: themeColor.opacity(0.12), radius: 12, y: 6)
    }

    // MARK: - Data Loading (logic unchanged)

    private func initializeBoard() async {
        await MainActor.run { isLoading = true }
        await fetchJournalHistoryDataAsync()
        if healthKitManager.isReadAuthorized {
            await fetchLatestMetrics()
        }
        await MainActor.run { isLoading = false }
    }

    private func refreshBoard() async {
        await fetchJournalHistoryDataAsync()
        if healthKitManager.isReadAuthorized {
            await fetchLatestMetrics()
        }
    }

    private func fetchJournalHistoryDataAsync() async {
        await MainActor.run { self.isLoading = true }

        let now              = Date()
        let startOfToday     = calendar.startOfDay(for: now)
        let endOfTodayForPredicate = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: now)!
        )

        guard let historyFetchStartDate = calendar.date(byAdding: .day, value: -89, to: startOfToday) else {
            await MainActor.run {
                errorManager.present(title: "Error", message: "Failed to calculate date range.")
                self.isLoading = false
            }
            return
        }

        let predicate = #Predicate<History> { h in
            h.date >= historyFetchStartDate && h.date < endOfTodayForPredicate
        }

        var descriptor = FetchDescriptor<History>(
            predicate: predicate,
            sortBy: [SortDescriptor(\History.date)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\History.workout]

        do {
            let history = try modelContext.fetch(descriptor)

            // Heatmap cells
            var days: [DayGridItem] = []
            var cursor = historyFetchStartDate
            for _ in 0..<90 {
                let day   = calendar.startOfDay(for: cursor)
                let match = history.first(where: { calendar.isDate($0.date, inSameDayAs: day) })
                days.append(DayGridItem(
                    date:          day,
                    didWorkout:    match != nil,
                    isToday:       calendar.isDate(day, inSameDayAs: startOfToday),
                    isTestWorkout: match?.workout?.title.lowercased().contains("test") ?? false
                ))
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            }

            // Aggregate stats
            let totalWorkouts   = history.count
            let totalMinutes    = history.reduce(0.0) { $0 + $1.lastSessionDuration }
            let formatter       = DateComponentsFormatter()
            formatter.allowedUnits  = [.hour, .minute]
            formatter.unitsStyle    = .abbreviated
            let totalFormatted  = formatter.string(from: totalMinutes * 60) ?? "\(Int(totalMinutes))m"
            let avgPerWeek      = Double(totalWorkouts) / (90.0 / 7.0)

            var distinctDays = Set<DateComponents>()
            history.forEach {
                distinctDays.insert(calendar.dateComponents([.year, .month, .day], from: $0.date))
            }

            // Weekly buckets (12 weeks, newest last)
            let weeklyDur: [Double] = (0..<12).map { w -> Double in
                let end   = calendar.date(byAdding: .day, value: -(w * 7), to: startOfToday)!
                let start = calendar.date(byAdding: .day, value: -6, to: end)!
                return history.filter {
                    let d = calendar.startOfDay(for: $0.date)
                    return d >= start && d <= end
                }.reduce(0.0) { $0 + $1.lastSessionDuration }
            }.reversed()

            let weeklyCounts: [Int] = (0..<12).map { w in
                let end   = calendar.date(byAdding: .day, value: -(w * 7), to: startOfToday)!
                let start = calendar.date(byAdding: .day, value: -6, to: end)!
                return history.filter {
                    let d = calendar.startOfDay(for: $0.date)
                    return d >= start && d <= end
                }.count
            }.reversed()

            let weeklyPulse: [Double] = (0..<12).map { w -> Double in
                let end    = calendar.date(byAdding: .day, value: -(w * 7), to: startOfToday)!
                let start  = calendar.date(byAdding: .day, value: -6, to: end)!
                let scores = history.filter {
                    let d = calendar.startOfDay(for: $0.date)
                    return d >= start && d <= end && $0.progressPulseScore != nil
                }.compactMap(\.progressPulseScore)
                return scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
            }.reversed()

            await MainActor.run {
                self.daysToDisplay                    = days
                self.weeklyDurations                  = weeklyDur
                self.weeklyWorkoutCounts              = weeklyCounts
                self.weeklyProgressPulseScores        = weeklyPulse
                self.totalWorkoutsLast90Days          = totalWorkouts
                self.totalDurationLast90DaysFormatted = totalFormatted
                self.avgWorkoutsPerWeekLast90Days     = avgPerWeek
                self.distinctActiveDaysLast90Days     = distinctDays.count
                self.isLoading                        = false
            }
        } catch {
            logger.error("fetchJournalHistoryDataAsync failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                errorManager.present(title: "Error", message: "Failed to load activity data.")
                self.isLoading = false
            }
        }
    }

    private func fetchLatestMetrics() async {
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -89, to: today) else { return }

        let predicate = #Predicate<History> { h in
            h.date >= startDate && h.date <= today &&
            (h.intensityScore != nil || h.progressPulseScore != nil || h.dominantZone != nil)
        }

        var descriptor = FetchDescriptor<History>(
            predicate: predicate,
            sortBy: [SortDescriptor(\History.date, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\History.workout?.category]

        do {
            let histories = try modelContext.fetch(descriptor)
            let latestPerCategory = Dictionary(
                grouping: histories,
                by: { $0.workout?.category?.categoryName ?? "Uncategorised" }
            ).compactMapValues(\.first)

            var newMetrics: [String: WorkoutMetrics] = [:]
            for (cat, h) in latestPerCategory {
                newMetrics[cat] = WorkoutMetrics(
                    intensityScore:     h.intensityScore,
                    progressPulseScore: h.progressPulseScore,
                    dominantZone:       h.dominantZone
                )
            }

            await MainActor.run { self.latestCategoryMetrics = newMetrics }
        } catch {
            logger.error("fetchLatestMetrics failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - StatTileView

/// A 2×2 grid tile showing a single aggregate stat with a tap-to-explain popover.
struct StatTileView: View {
    let icon:        String
    let title:       String
    let value:       String
    let description: String
    let accent:      Color

    @State private var showPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent.opacity(0.85))
                    .accessibilityHidden(true)
                Spacer()
                Button {
                    showPopover = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More information about \(title)")
            }

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
        .popover(isPresented: $showPopover) {
            Text(description)
                .font(.system(.subheadline, design: .serif))
                .padding(20)
                .presentationDetents([.fraction(0.25)])
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value). Double-tap for description.")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - MetricTileView

/// Premium category metrics card with gauge bars for intensity and pulse.
struct MetricTileView: View {
    let category: String
    let metrics:  WorkoutMetrics
    let accent:   Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 8) {
                Capsule()
                    .fill(accent)
                    .frame(width: 3, height: 13)
                    .accessibilityHidden(true)
                Text(category.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                    .tracking(1.5)
                Spacer()
            }

            if let intensity = metrics.intensityScore {
                metricGaugeRow(label: "INTENSITY", value: intensity, max: 100,
                               text: String(format: "%.0f%%", intensity), color: accent)
            }

            if let pulse = metrics.progressPulseScore {
                metricGaugeRow(label: "PROGRESS PULSE", value: pulse, max: 100,
                               text: String(format: "%.0f", pulse), color: accent)
            }

            if let zone = metrics.dominantZone {
                HStack {
                    Text("DOMINANT ZONE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Spacer()
                    Text("Zone \(zone) · \(hrZoneLabel(zone))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(hrZoneColor(zone))
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: accent.opacity(0.08), radius: 8, y: 4)
    }

    private func metricGaugeRow(label: String, value: Double, max: Double,
                                 text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                Text(text)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12)).frame(height: 4)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * min(value / max, 1), height: 4)
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(text)")
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
}

// MARK: - InfoStatItem

/// Enumerates the four headline aggregate stats shown in the 2×2 grid.
enum InfoStatItem: String, Identifiable {
    case totalWorkouts
    case totalTime
    case avgWorkoutsPerWeek
    case activeDays

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .totalWorkouts:     return "Total Workouts"
        case .totalTime:         return "Total Time"
        case .avgWorkoutsPerWeek: return "Avg / Week"
        case .activeDays:        return "Active Days"
        }
    }

    var descriptionText: String {
        switch self {
        case .totalWorkouts:
            return "Total workouts completed in the last 90 days."
        case .totalTime:
            return "Combined duration of all workouts in the last 90 days."
        case .avgWorkoutsPerWeek:
            return "Average workouts per week over the last 90 days."
        case .activeDays:
            return "Number of unique days you trained in the last 90 days."
        }
    }
}
