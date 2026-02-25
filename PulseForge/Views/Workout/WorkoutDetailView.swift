//
//  WorkoutDetailView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Detailed workout view with start session, exercises, summary, and history.
//  - Premium metrics (intensity, progress pulse, dominant zone) gated behind subscription.
//  - HealthKit data displayed on-device only.
//  - Full VoiceOver accessibility, dynamic type, and high contrast support.
//  - Consistent with app-wide theming and future Watch parity.
//

import SwiftUI
import SwiftData


/// A SwiftUI view that presents detailed information about a specific workout.
/// This view includes sections for starting the workout, category details, exercises list,
/// workout summary, and recent history. It ensures accessibility compliance by providing
/// appropriate labels, hints, and grouped elements for VoiceOver support.
struct WorkoutDetailView: View {
    // MARK: - Properties
    
    /// The workout object containing details to display.
    let workout: Workout
    
    /// The selected theme color, stored in AppStorage.
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    /// Static DateFormatter for consistent schedule date formatting.
    /// This formatter is used to display dates in a medium style with short time.
    private static let scheduleDateFormatterStatic: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // MARK: - Body
    
    var body: some View {
        // Determine the tint color based on the workout category or default to blue.
        let tintColor = workout.category?.categoryColor.color ?? .blue
        ZStack {
            Color.proBackground
                .ignoresSafeArea()
            contentStack(tintColor: tintColor)
        }
        // Support dynamic type sizes for accessibility.
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
    
    /// Builds the main content stack with navigation and form.
    /// - Parameter tintColor: The color used for tinting UI elements.
    /// - Returns: A NavigationStack containing the form with workout details.
    @ViewBuilder
    private func contentStack(tintColor: Color) -> some View {
        NavigationStack {
            Form {
                beginWorkoutSection
                categorySection
                exercisesSection
                summarySection
                journalSection
            }
            .fontDesign(.serif)
            .scrollContentBackground(.hidden)
            .navigationTitle("Workout Review")
            .navigationBarTitleDisplayMode(.inline)
            .tint(tintColor)
            .toolbar { editToolbar(tintColor: tintColor) }
            // Add accessibility label for the entire navigation stack.
            .accessibilityLabel("Workout detail view")
        }
    }
    
    /// Provides the toolbar content for editing the workout.
    /// - Parameter tintColor: The color for the edit button.
    /// - Returns: ToolbarItem with a navigation link to the edit view.
    @ToolbarContentBuilder
    private func editToolbar(tintColor: Color) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(destination: WorkoutEditView(workout: workout)) {
                Text("Edit")
                    .font(.system(.callout).weight(.medium))
                    .fontDesign(.serif)
                    .foregroundStyle(.primary)
                    .padding(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                    .background(tintColor)
                    .cornerRadius(6)
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor)
            .accessibilityLabel("Edit workout")
            .accessibilityHint("Opens the workout editor")
            .accessibilityAddTraits(.isButton)
        }
    }
    
    // MARK: - Subviews
    
    /// Section for starting a workout session.
    /// This section contains a navigation link to begin the workout.
    private var beginWorkoutSection: some View {
        Section {
            NavigationLink {
                WorkoutSessionView(workout: workout)
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .accessibilityHidden(true) // Decorative icon.
                    Text("Begin Workout")
                }
                .font(.headline)
                .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
            }
            .accessibilityIdentifier("beginWorkoutLink")
            .accessibilityLabel("Begin workout")
            .accessibilityHint("Start the workout session")
            .accessibilityAddTraits(.isButton)
        } header: {
            Text("Start Session")
                .font(.title3)
                .fontDesign(.serif)
                .fontWeight(.semibold)
                .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
                .accessibilityAddTraits(.isHeader)
        }
    }
    
    /// Section for displaying the workout category.
    /// Shows the category name and symbol if available, or a placeholder message.
    private var categorySection: some View {
        Section {
            if let category = workout.category {
                HStack {
                    Image(systemName: category.symbol)
                        .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
                        .font(.system(size: 16))
                        .accessibilityHidden(true) // Decorative icon.
                    Text(category.categoryName)
                        .foregroundStyle(.primary)
                        .font(.callout)
                        .fontDesign(.serif)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Category: \(category.categoryName)")
            } else {
                Text("No category selected")
                    .font(.callout)
                    .fontDesign(.serif)
                    .italic()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("No workout category selected")
            }
        } header: {
            Text("Workout Category")
                .font(.title3)
                .fontDesign(.serif)
                .fontWeight(.semibold)
                .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
                .accessibilityAddTraits(.isHeader)
        }
    }
    
    /// Section for listing exercises, including rounds if enabled.
    /// Displays exercises with optional round numbers and ensures accessibility by combining elements.
    private var exercisesSection: some View {
        Section {
            let accent = workout.category?.categoryColor.color ?? .secondary
            let baseCount = workout.sortedExercises.count
            let hasRounds = workout.roundsEnabled && workout.roundsQuantity > 1
            
            if hasRounds {
                Label("\(workout.roundsQuantity) Rounds", systemImage: "repeat")
                    .font(.subheadline.bold())
                    .foregroundStyle(accent)
                    .accessibilityLabel("Number of rounds")
                    .accessibilityValue("\(workout.roundsQuantity) rounds")
            }
            ForEach(workout.effectiveExercises.indices, id: \.self) { index in
                let exercise = workout.effectiveExercises[index]
                let roundNumber = hasRounds ? (index / baseCount + 1) : nil
                HStack(spacing: 10) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(accent)
                        .accessibilityHidden(true) // Decorative icon.
                    Text(roundNumber != nil ? "Round \(roundNumber!): \(exercise.name)" : exercise.name)
                        .foregroundStyle(.primary)
                }
                .font(.system(size: 16))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(roundNumber != nil ? "Round \(roundNumber!), \(exercise.name)" : exercise.name)
            }
        } header: {
            Text("Exercises")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
                .accessibilityAddTraits(.isHeader)
        }
    }
    
    // MARK: - SUMMARY SECTION
    /// Section for displaying the workout summary.
    /// Includes fastest time and generated summary, with accessibility labels for each part.
    private var summarySection: some View {
        Section {
            if let fastestTime = workout.fastestTime, fastestTime > 0 {
                let formattedFastest = formatDuration(fastestTime * 60)
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true) // Decorative icon.
                    Text("Fastest Time:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedFastest)
                        .foregroundStyle(.primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Fastest Time: \(formattedFastest)")
            } else {
                HStack {
                    Image(systemName: "star")
                        .foregroundStyle(.gray)
                        .accessibilityHidden(true) // Decorative icon.
                    Text("No time recorded yet")
                        .italic()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No fastest time recorded")
            }
            if let summary = workout.generatedSummary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Workout summary: \(summary)")
            } else {
                Text("Complete at least one workout to generate a summary.")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("No workout summary available")
            }
        } header: {
            Text("Workout Summary")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
                .accessibilityAddTraits(.isHeader)
        }
    }
    
    /// Section for displaying recent workout history.
    /// Shows up to three recent entries with navigation links to details.
    private var journalSection: some View {
        Section {
            journalEntrySectionContent
        } header: {
            Text("Recent History")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(workout.category?.categoryColor.color ?? .gray)
                .accessibilityAddTraits(.isHeader)
        }
    }
    
    /// Content for the history section, showing up to three recent sessions.
    /// Each entry is a navigation link with date and duration, grouped for accessibility.
    @ViewBuilder
    private var journalEntrySectionContent: some View {
        let entries = (workout.history ?? [])
            .sorted { $0.date > $1.date }
        
        if entries.isEmpty {
            Text("No completed sessions yet.")
                .foregroundStyle(.secondary)
                .fontDesign(.serif)
                .italic()
                .accessibilityLabel("No completed workout sessions")
        } else {
            let recentEntries = Array(entries.prefix(3))
            
            ForEach(recentEntries, id: \.id) { historyItem in
                NavigationLink(destination: JournalEntryView(history: historyItem, workout: workout)) {
                    HistoryRowView(
                        historyItem: historyItem,
                        tintColor: workout.category?.categoryColor.color ?? .secondary
                    )
                }
                .accessibilityHint("Tap to view details for this workout history entry")
                .accessibilityAddTraits(.isButton)
            }
            
            if let mostRecent = entries.first {
                NavigationLink("View Most Recent Entry") {
                    JournalEntryView(history: mostRecent, workout: workout)
                }
                .foregroundStyle(.blue)
                .font(.subheadline)
                .accessibilityLabel("View most recent workout history entry")
                .accessibilityHint("Opens the most recent journal entry")
                .accessibilityAddTraits(.isButton)
            }
        }
    }
    
    private struct HistoryRowView: View {
        let historyItem: History
        let tintColor: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(tintColor)
                        .font(.system(size: 16))
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading) {
                        Text(historyItem.date, style: .date)
                            .font(.body)
                            .fontDesign(.serif)
                        
                        Text("Duration: \(historyItem.formattedDuration)")
                            .font(.caption)
                            .fontDesign(.serif)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Workout on \(historyItem.date, style: .date), Duration: \(historyItem.formattedDuration)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Converts a heart rate zone integer to a descriptive string.
    /// - Parameter zone: The heart rate zone number (optional).
    /// - Returns: A string describing the zone or nil if zone is nil.
    private func zoneDescription(for zone: Int?) -> String? {
        guard let zone = zone else { return nil }
        switch zone {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "Unknown"
        }
    }
    
    // MARK: - Duration Formatting
    /// Formats a duration in seconds into a human-readable string.
    /// Examples: 75 -> "1m 15s", 3661 -> "1h 1m 1s"
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
