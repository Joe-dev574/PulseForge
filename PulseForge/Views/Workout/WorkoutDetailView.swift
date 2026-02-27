//
//  WorkoutDetailView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Detailed workout view with start session, exercises, summary, and history.
//  - Premium metrics gated behind subscription.
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
    let workout: Workout
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    // MARK: - Body
    var body: some View {
        let tintColor = workout.category?.categoryColor.color ?? themeColor
        
        ZStack {
            Color.proBackground.ignoresSafeArea()
            contentStack(tintColor: tintColor)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
    
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
            .accessibilityLabel("Workout detail view")
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private func editToolbar(tintColor: Color) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(destination: WorkoutEditView(workout: workout)) {
                Text("Edit")
                    .font(.system(.callout).weight(.medium))
                    .fontDesign(.serif)
                    .foregroundStyle(.primary)
                    .padding(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor)
            .accessibilityLabel("Edit workout")
            .accessibilityHint("Opens the workout editor")
            .accessibilityAddTraits(.isButton)
        }
    }
    
    // MARK: - Sections
    private var beginWorkoutSection: some View {
        Section {
            NavigationLink {
                WorkoutSessionView(workout: workout)
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .accessibilityHidden(true)
                    Text("Begin Workout")
                }
                .font(.headline)
                .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
            }
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
    
    private var categorySection: some View {
        Section {
            if let category = workout.category {
                HStack {
                    Image(systemName: category.symbol)
                        .foregroundStyle(category.categoryColor.color)
                        .font(.system(size: 16))
                        .accessibilityHidden(true)
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
                        .accessibilityHidden(true)
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
    
    private var summarySection: some View {
        Section {
            if let fastestTime = workout.fastestTime, fastestTime > 0 {
                let formattedFastest = formatDuration(fastestTime * 60)
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
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
                        .accessibilityHidden(true)
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
    
    @ViewBuilder
    private var journalEntrySectionContent: some View {
        let entries = (workout.history ?? []).sorted { $0.date > $1.date }
        
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
    
    // MARK: - Helpers
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
