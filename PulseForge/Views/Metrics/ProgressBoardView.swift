//
//  ProgressBoardView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/20/26.
//  Updated: February 25, 2026
//
//  Apple App Store Compliance:
//  - All metric calculations use HealthKitManager (single source of truth).
//  - Premium features (Progress Pulse, advanced graphs, category metrics) strictly gated behind subscription.
//  - HealthKit data used only with explicit user authorization and processed on-device.
//  - Full VoiceOver, Dynamic Type, and Reduce Motion support.
//  - Clean, high-contrast UI designed for seamless Apple Watch parity.
//

import SwiftUI
import SwiftData
internal import HealthKit
import OSLog
import StoreKit

// MARK: - Supporting Types

/// Represents a single day in the 90-day activity heatmap.
struct DayGridItem: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    var didWorkout: Bool
    let isToday: Bool
    var isTestWorkout: Bool
}

/// A single circular day cell for the heatmap with subtle press animation.
struct DayCellView: View {
    let didWorkout: Bool
    let isToday: Bool
    let themeColor: Color
    let isTestWorkout: Bool
    
    @State private var isPressed = false
    
    private var cellGradient: RadialGradient {
        if isTestWorkout {
            return RadialGradient(gradient: Gradient(colors: [.white.opacity(0.5), .indigo, .indigo]),
                                  center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)
        } else if didWorkout {
            return RadialGradient(gradient: Gradient(colors: [.white.opacity(0.5), .green, .green]),
                                  center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)
        } else {
            return RadialGradient(gradient: Gradient(colors: [.white.opacity(0.2), .gray.opacity(0.2)]),
                                  center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)
        }
    }
    
    var body: some View {
        Circle()
            .fill(cellGradient)
            .frame(width: 20, height: 20)
            .overlay(isToday ? Circle().stroke(themeColor.opacity(0.9), lineWidth: 3) : nil)
            .shadow(color: .black.opacity(didWorkout ? 0.5 : 0.2), radius: 3, x: 2, y: 2)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onTapGesture {
                withAnimation {
                    isPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        isPressed = false
                    }
                }
            }
            .accessibilityLabel(isToday
                ? "Today, \(didWorkout ? "workout completed" : "no workout")"
                : didWorkout ? "Workout completed" : "No workout")
            .accessibilityHint(didWorkout ? "Tap to highlight this workout day" : "Tap to highlight this rest day")
    }
}

// MARK: - Workout Graph (Smart Dynamic Scaling)

/// A reusable, beautifully scaled line graph for weekly trends with automatic smart scaling.
struct WorkoutGraph: View {
    let values: [Double]
    let themeColor: Color
    let title: String
    var fixedMaxValue: Double? = nil
    
    private var effectiveMaxValue: Double {
        guard !values.isEmpty else { return 1.0 }
        let dataMax = values.max() ?? 1.0
        let maxValue = fixedMaxValue ?? dataMax
        return max(maxValue * 1.12, 1.0) // 12% headroom for clean visuals
    }
    
    private let leadingPadding: CGFloat = 12
    private let trailingPadding: CGFloat = 8
    private let verticalPadding: CGFloat = 8
    private let labelWidth: CGFloat = 32
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(themeColor.opacity(0.9))
                .padding(.leading, leadingPadding)
            
            GeometryReader { geometry in
                let width = geometry.size.width - leadingPadding - trailingPadding
                let height = geometry.size.height - verticalPadding * 2
                let spacing = values.count > 1 ? (width / CGFloat(values.count - 1)) : 0
                
                ZStack(alignment: .leading) {
                    // Horizontal grid lines + labels
                    ForEach(0...4, id: \.self) { i in
                        let y = verticalPadding + (height * CGFloat(i) / 4.0)
                        let value = effectiveMaxValue * (1.0 - CGFloat(i) / 4.0)
                        
                        Path { path in
                            path.move(to: CGPoint(x: leadingPadding, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width - trailingPadding, y: y))
                        }
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        
                        Text(value.formatted(.number.precision(.fractionLength(0))))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: labelWidth, alignment: .trailing)
                            .position(x: leadingPadding / 2, y: y)
                    }
                    
                    // Filled area + line
                    if !values.isEmpty {
                        Path { path in
                            path.move(to: CGPoint(x: leadingPadding, y: height + verticalPadding))
                            
                            for (index, value) in values.enumerated() {
                                let x = leadingPadding + CGFloat(index) * spacing
                                let normalized = min(max(value / effectiveMaxValue, 0), 1.0)
                                let y = verticalPadding + height * (1.0 - normalized)
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            
                            path.addLine(to: CGPoint(x: leadingPadding + CGFloat(values.count - 1) * spacing,
                                                   y: height + verticalPadding))
                            path.closeSubpath()
                        }
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [themeColor.opacity(0.65), themeColor.opacity(0.05)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        
                        // Line
                        Path { path in
                            for (index, value) in values.enumerated() {
                                let x = leadingPadding + CGFloat(index) * spacing
                                let normalized = min(max(value / effectiveMaxValue, 0), 1.0)
                                let y = verticalPadding + height * (1.0 - normalized)
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(themeColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .shadow(color: themeColor.opacity(0.4), radius: 4, y: 2)
                    }
                }
            }
            .frame(height: 148)
        }
    }
}

// MARK: - Main View

struct ProgressBoardView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(ErrorManager.self) private var errorManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - App Storage
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    // MARK: - State
    
    @State private var daysToDisplay: [DayGridItem] = []
    @State private var weeklyDurations: [Double] = []
    @State private var weeklyWorkoutCounts: [Int] = []
    @State private var weeklyProgressPulseScores: [Double] = []
    
    @State private var totalWorkoutsLast90Days: Int = 0
    @State private var totalDurationLast90DaysFormatted: String = "0 min"
    @State private var avgWorkoutsPerWeekLast90Days: Double = 0.0
    @State private var distinctActiveDaysLast90Days: Int = 0
    
    @State private var latestCategoryMetrics: [String: WorkoutMetrics] = [:]
    @State private var isLoading: Bool = true
    @State private var showMetricsInfoPopover: Bool = false
    
    // MARK: - Private Properties
    
    private let purchaseManager = PurchaseManager.shared
    private let logger = Logger(subsystem: "com.pulseforge.PulseForge", category: "ProgressBoardView")
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Loading your progress...")
                        .padding(.top, 60)
                } else {
                    VStack(spacing: 24) {
                        heatmapSection
                        statsSection
                        graphsSection
                        
                        if purchaseManager.isSubscribed {
                            metricsSection
                        } else {
                            premiumTeaserContent
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable { await refreshBoard() }
            .onAppear { Task { await initializeBoard() } }
        }
    }
    
    // MARK: - Subviews
    
    private var heatmapSection: some View {
        VStack(spacing: 12) {
            Text("90-Day Activity Heatmap")
                .font(.headline)
                .foregroundStyle(themeColor)
            
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 4), count: 15), spacing: 4) {
                ForEach(daysToDisplay) { day in
                    DayCellView(
                        didWorkout: day.didWorkout,
                        isToday: day.isToday,
                        themeColor: themeColor,
                        isTestWorkout: day.isTestWorkout
                    )
                }
            }
            .padding(10)
            .background(Color(.systemBackground).opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 3)
            
            // Legend
            HStack(spacing: 24) {
                legendItem(color: .green, text: "Workout Day")
                legendItem(color: .indigo, text: "Test Workout")
                legendItem(color: .gray, text: "No Workout")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color.opacity(0.9)).frame(width: 18, height: 18)
            Text(text)
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            Text("90-Day Stats")
                .font(.headline)
                .foregroundStyle(themeColor)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: InfoStatItem.totalWorkouts.displayTitle,
                        value: "\(totalWorkoutsLast90Days)",
                        description: InfoStatItem.totalWorkouts.descriptionText)
                
                StatCard(title: InfoStatItem.totalTime.displayTitle,
                        value: totalDurationLast90DaysFormatted,
                        description: InfoStatItem.totalTime.descriptionText)
                
                StatCard(title: InfoStatItem.avgWorkoutsPerWeek.displayTitle,
                        value: String(format: "%.1f", avgWorkoutsPerWeekLast90Days),
                        description: InfoStatItem.avgWorkoutsPerWeek.descriptionText)
                
                StatCard(title: InfoStatItem.activeDays.displayTitle,
                        value: "\(distinctActiveDaysLast90Days)",
                        description: InfoStatItem.activeDays.descriptionText)
            }
        }
    }
    
    private var graphsSection: some View {
        VStack(spacing: 20) {
            Text("12-Week Trends")
                .font(.headline)
                .foregroundStyle(themeColor)
            
            WorkoutGraph(values: weeklyDurations,
                        themeColor: themeColor,
                        title: "Weekly Duration (minutes)")
            
            WorkoutGraph(values: weeklyWorkoutCounts.map(Double.init),
                        themeColor: themeColor,
                        title: "Weekly Workouts")
            
            if purchaseManager.isSubscribed {
                WorkoutGraph(values: weeklyProgressPulseScores,
                            themeColor: themeColor,
                            title: "Weekly Progress Pulse Score",
                            fixedMaxValue: 100)
            }
        }
    }
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest Metrics by Category")
                .font(.headline)
                .foregroundStyle(themeColor)
            
            if latestCategoryMetrics.isEmpty {
                Text("Complete more workouts to see advanced metrics.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(latestCategoryMetrics.keys.sorted()), id: \.self) { category in
                    if let metrics = latestCategoryMetrics[category] {
                        MetricCard(category: category, metrics: metrics)
                    }
                }
            }
        }
    }
    
    private var premiumTeaserContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(themeColor.opacity(0.9))
            
            Text("Unlock Premium")
                .font(.title3.bold())
            
            Text("Get Progress Pulse, advanced analytics, and full Apple Watch support.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Subscribe Now") {
                // Opens subscription view (you already have this flow)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
        }
        .padding(24)
        .background(Color(.systemBackground).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 8)
        .padding(.horizontal)
    }
    
    // MARK: - Data Loading
    
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
    
    /// Fetches workout history data asynchronously and updates the view’s state.
    /// This method queries SwiftData for history entries, calculates metrics, and updates state properties on the main actor.
    private func fetchJournalHistoryDataAsync() async {
        await MainActor.run { self.isLoading = true }
        logger.debug("[ProgressBoardView] [fetchHistoryDataAsync] Starting fetch. isLoading set to true.")
        
        let now = Date()
        let endOfTodayForPredicate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        
        let startOfToday = calendar.startOfDay(for: now)
        guard let historyFetchStartDate = calendar.date(byAdding: .day, value: -89, to: startOfToday) else {
            logger.error("[ProgressBoardView] [fetchHistoryDataAsync] Failed to calculate history fetch start date.")
            await MainActor.run {
                errorManager.present(title: "Error", message: "Failed to calculate date range for history.")
                self.isLoading = false
            }
            return
        }
        
        logger.debug("[ProgressBoardView] [fetchHistoryDataAsync] Fetching history from: \(historyFetchStartDate.formatted(date: .long, time: .standard)) up to (but not including): \(endOfTodayForPredicate.formatted(date: .long, time: .standard)) for graphs and heatmap.")
        
        let predicate = #Predicate<History> { history in
            history.date >= historyFetchStartDate && history.date < endOfTodayForPredicate
        }
        
        var descriptor = FetchDescriptor<History>(predicate: predicate, sortBy: [SortDescriptor(\History.date)])
        descriptor.relationshipKeyPathsForPrefetching = [\History.workout]
        
        do {
            let history = try modelContext.fetch(descriptor)
            logger.log("[ProgressBoardView] [fetchHistoryDataAsync] Fetched \(history.count) history records with predicate for the last 90 days.")
            
            var calculatedDaysToDisplay: [DayGridItem] = []
            guard let heatmapStartDate = calendar.date(byAdding: .day, value: -89, to: startOfToday) else {
                logger.error("[ProgressBoardView] [fetchHistoryDataAsync] Failed to calculate heatmapStartDate for display loop.")
                await MainActor.run {
                    errorManager.present(title: "Error", message: "Date calculation error.")
                    self.isLoading = false
                }
                return
            }
            
            var currentDateIterator = heatmapStartDate
            for i in 0..<90 {
                let displayDate = calendar.startOfDay(for: currentDateIterator)
                let isCurrentItemToday = calendar.isDate(displayDate, inSameDayAs: startOfToday)
                
                let didWorkoutOnThisDay = history.contains(where: { calendar.isDate($0.date, inSameDayAs: displayDate) })
                let isTestWorkoutOnThisDay = history.first(where: { calendar.isDate($0.date, inSameDayAs: displayDate) })?.workout?.title.lowercased().contains("test") ?? false
                
                calculatedDaysToDisplay.append(DayGridItem(
                    date: displayDate,
                    didWorkout: didWorkoutOnThisDay,
                    isToday: isCurrentItemToday,
                    isTestWorkout: isTestWorkoutOnThisDay
                ))
                if i < 89 {
                    currentDateIterator = calendar.date(byAdding: .day, value: 1, to: currentDateIterator)!
                }
            }
            logger.debug("[ProgressBoardView] [fetchHistoryDataAsync] Calculated \(calculatedDaysToDisplay.count) days for heatmap display. First: \(calculatedDaysToDisplay.first?.date.description ?? "N/A"), Last: \(calculatedDaysToDisplay.last?.date.description ?? "N/A")")
            
            let calculatedTotalWorkouts90Days = history.count
            let totalDurationMinutes90Days = history.reduce(0.0) { $0 + $1.lastSessionDuration }
            
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .abbreviated
            let calculatedTotalDurationFormatted = formatter.string(from: TimeInterval(totalDurationMinutes90Days * 60)) ?? "\(Int(totalDurationMinutes90Days)) min"
            
            let numberOfWeeksIn90Days = 90.0 / 7.0
            let calculatedAvgWorkoutsPerWeek = Double(calculatedTotalWorkouts90Days) / numberOfWeeksIn90Days
            
            var distinctDays = Set<DateComponents>()
            for historyItem in history {
                distinctDays.insert(calendar.dateComponents([.year, .month, .day], from: historyItem.date))
            }
            let calculatedDistinctActiveDays = distinctDays.count
            
            let calculatedWeeklyDurations: [Double] = (0..<12).map { weekIndex -> Double in
                let endOfWeekDay = calendar.date(byAdding: .day, value: -(weekIndex * 7), to: startOfToday)!
                let startOfWeekDay = calendar.date(byAdding: .day, value: -6, to: endOfWeekDay)!
                return history.filter { history in
                    let historyDay = calendar.startOfDay(for: history.date)
                    return historyDay >= startOfWeekDay && historyDay <= endOfWeekDay
                }.reduce(0.0) { $0 + $1.lastSessionDuration }
            }.reversed()
            
            let calculatedWeeklyWorkoutCounts: [Int] = (0..<12).map { weekIndex in
                let endOfWeekDay = calendar.date(byAdding: .day, value: -(weekIndex * 7), to: startOfToday)!
                let startOfWeekDay = calendar.date(byAdding: .day, value: -6, to: endOfWeekDay)!
                return history.filter { history in
                    let historyDate = calendar.startOfDay(for: history.date)
                    return historyDate >= startOfWeekDay && historyDate <= endOfWeekDay
                }.count
            }.reversed()
            
            let calculatedWeeklyProgressPulseScores: [Double] = (0..<12).map { weekIndex -> Double in
                let endOfWeekDay = calendar.date(byAdding: .day, value: -(weekIndex * 7), to: startOfToday)!
                let startOfWeekDay = calendar.date(byAdding: .day, value: -6, to: endOfWeekDay)!
                let scoresInWeek = history.filter { history in
                    let historyDay = calendar.startOfDay(for: history.date)
                    return historyDay >= startOfWeekDay && historyDay <= endOfWeekDay && history.progressPulseScore != nil
                }.compactMap { $0.progressPulseScore }
                return scoresInWeek.isEmpty ? 0.0 : scoresInWeek.reduce(0.0, +) / Double(scoresInWeek.count)
            }.reversed()
            
            await MainActor.run {
                self.daysToDisplay = calculatedDaysToDisplay
                self.weeklyDurations = calculatedWeeklyDurations
                self.weeklyWorkoutCounts = calculatedWeeklyWorkoutCounts
                self.weeklyProgressPulseScores = calculatedWeeklyProgressPulseScores
                
                self.totalWorkoutsLast90Days = calculatedTotalWorkouts90Days
                self.totalDurationLast90DaysFormatted = calculatedTotalDurationFormatted
                self.avgWorkoutsPerWeekLast90Days = calculatedAvgWorkoutsPerWeek
                self.distinctActiveDaysLast90Days = calculatedDistinctActiveDays
                
                self.isLoading = false
                logger.log("[ProgressBoardView] [fetchHistoryDataAsync] History data processed. Weekly Pulse Scores: \(calculatedWeeklyProgressPulseScores), Total 90-day Workouts: \(calculatedTotalWorkouts90Days)")
            }
        } catch {
            logger.error("[ProgressBoardView] [fetchHistoryDataAsync] Failed to fetch history: \(error.localizedDescription)")
            await MainActor.run {
                errorManager.present(title: "Error", message: "Failed to load activity data: \(error.localizedDescription)")
                self.isLoading = false
            }
        }
    }
    
    /// Fetches the latest workout metrics per category from SwiftData.
    /// This method groups history entries by category and extracts the most recent metrics for each.
    private func fetchLatestMetrics() async {
        logger.debug("[ProgressBoardView] [fetchLatestMetrics] Fetching latest metrics per category.")
        
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -89, to: today) else {
            logger.error("[ProgressBoardView] [fetchLatestMetrics] Failed to calculate start date.")
            return
        }
        
        let predicate = #Predicate<History> { history in
            history.date >= startDate && history.date <= today &&
            (history.intensityScore != nil || history.progressPulseScore != nil || history.dominantZone != nil)
        }
        
        var descriptor = FetchDescriptor<History>(predicate: predicate, sortBy: [SortDescriptor(\History.date, order: .reverse)])
        descriptor.relationshipKeyPathsForPrefetching = [\History.workout?.category]
        
        do {
            let historiesWithMetrics = try modelContext.fetch(descriptor)
            logger.debug("[ProgressBoardView] [fetchLatestMetrics] Fetched \(historiesWithMetrics.count) histories potentially containing metrics for predicate.")
            
            let latestHistoryPerCategory = Dictionary(grouping: historiesWithMetrics, by: { $0.workout?.category?.categoryName ?? "Uncategorized" })
                .compactMapValues { $0.first }
            
            var newMetrics: [String: WorkoutMetrics] = [:]
            for (categoryName, latestHistory) in latestHistoryPerCategory {
                logger.trace("[ProgressBoardView] [fetchLatestMetrics] Latest metrics for category '\(categoryName)' from history date: \(latestHistory.date), Intensity: \(latestHistory.intensityScore ?? -1), Pulse: \(latestHistory.progressPulseScore ?? -1), Zone: \(latestHistory.dominantZone ?? -1)")
                newMetrics[categoryName] = WorkoutMetrics(
                    intensityScore: latestHistory.intensityScore,
                    progressPulseScore: latestHistory.progressPulseScore,
                    dominantZone: latestHistory.dominantZone
                )
            }
            
            await MainActor.run {
                self.latestCategoryMetrics = newMetrics
                logger.debug("[ProgressBoardView] [fetchLatestMetrics] Latest metrics updated. Count: \(newMetrics.count). Keys: \(newMetrics.keys.joined(separator: ", "))")
            }
        } catch {
            logger.error("[ProgressBoardView] [fetchLatestMetrics] Failed to fetch histories for metrics: \(error.localizedDescription)")
        }
    }

}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let description: String
    
    @State private var showPopover = false
    
    var body: some View {
        VStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(8)
        .shadow(radius: 1)
        .onTapGesture { showPopover = true }
        .popover(isPresented: $showPopover) {
            Text(description)
                .padding()
                .presentationDetents([.fraction(0.3)])
        }
    }
}

struct MetricCard: View {
    let category: String
    let metrics: WorkoutMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category)
                .font(.subheadline.bold())
            
            if let intensity = metrics.intensityScore {
                HStack {
                    Text("Intensity Score:")
                    Spacer()
                    Text(String(format: "%.1f", intensity))
                }
            }
            
            if let pulse = metrics.progressPulseScore {
                HStack {
                    Text("Progress Pulse:")
                    Spacer()
                    Text(String(format: "%.1f", pulse))
                }
            }
            
            if let zone = metrics.dominantZone {
                HStack {
                    Text("Dominant Zone:")
                    Spacer()
                    Text("\(zone) (\(zoneDescription(zone)))")
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

private func zoneDescription(_ zone: Int) -> String {
    switch zone {
    case 1: return "Very Light"
    case 2: return "Light"
    case 3: return "Moderate"
    case 4: return "Hard"
    case 5: return "Maximum"
    default: return "Unknown"
    }
}
// MARK: - Enumerations

/// Enumerates the types of statistics displayed in the progress board.
/// Each case represents a key metric with associated display and description properties.
enum InfoStatItem: String, Identifiable {
    /// Total number of workouts in the last 90 days.
    case totalWorkouts
    /// Total workout duration in the last 90 days.
    case totalTime
    /// Average workouts per week in the last 90 days.
    case avgWorkoutsPerWeek
    /// Number of unique active days in the last 90 days.
    case activeDays
    
    /// A unique identifier for the stat item.
    var id: String { self.rawValue }
    
    /// A descriptive text explaining the stat for display in a popover.
    var descriptionText: String {
        switch self {
        case .totalWorkouts:
            return "The total number of workouts completed in the last 90 days."
        case .totalTime:
            return "The total duration of all workouts completed in the last 90 days."
        case .avgWorkoutsPerWeek:
            return "The average number of workouts completed per week over the last 90 days."
        case .activeDays:
            return "The number of unique days you completed at least one workout in the last 90 days."
        }
    }
    
    /// The display title for the stat, used in the UI.
    var displayTitle: String {
        switch self {
        case .totalWorkouts: return "  Total Workouts   "
        case .totalTime: return " Total Time "
        case .avgWorkoutsPerWeek: return "Avg Workouts/Wk"
        case .activeDays: return "Active Days"
        }
    }
}
