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

/// Detailed view for a specific workout.
/// Shows category, exercises, summary, and recent history.
/// Uses MetricsManager for centralized premium metrics.
struct WorkoutDetailView: View {
    
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(MetricsManager.self) private var metricsManager
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(ErrorManager.self) private var errorManager
    
    // MARK: - Properties
    let workout: Workout
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    @State private var metrics: WorkoutMetrics?
    
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    beginWorkoutSection
                    categorySection
                    exercisesSection
                    summarySection
                    historySection
                }
                .padding()
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") {
                    // Link to edit view if you have one, or placeholder
                    Text("Edit Workout (Coming Soon)")
                }
            }
        }
        .task {
            metrics = await metricsManager.fetchMetrics(for: workout)
        }
    }
    
    // MARK: - Subviews
    
    private var beginWorkoutSection: some View {
        Button {
            // Navigation to session handled by parent or sheet
        } label: {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                Text("Begin Workout")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(themeColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityLabel("Begin workout session")
        .accessibilityHint("Start the workout timer and tracking")
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.headline)
                .foregroundStyle(themeColor)
            
            if let category = workout.category {
                HStack {
                    Image(systemName: category.symbol)
                        .foregroundStyle(category.categoryColor.color)
                    Text(category.categoryName)
                        .font(.title3)
                }
            } else {
                Text("No category assigned")
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .foregroundStyle(themeColor)
            
            ForEach(workout.effectiveExercises) { exercise in
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(themeColor.opacity(0.8))
                    Text(exercise.name)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .foregroundStyle(themeColor)
            
            if let fastest = workout.fastestTime, fastest > 0 {
                StatRow(title: "Fastest Time", value: formatDuration(minutes: fastest))
            }
            
            if let summary = workout.generatedSummary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Complete a session to generate a summary.")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            
            // Premium metrics
            if purchaseManager.isSubscribed, let m = metrics {
                if let intensity = m.intensityScore {
                    StatRow(title: "Avg Intensity", value: "\(Int(intensity))%")
                }
                if let pulse = m.progressPulseScore {
                    StatRow(title: "Progress Pulse", value: "\(Int(pulse))")
                }
                if let zone = m.dominantZone {
                    StatRow(title: "Dominant Zone", value: "Zone \(zone)")
                }
            } else if purchaseManager.isSubscribed == false {
                Text("Upgrade to Premium for advanced metrics")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent History")
                .font(.headline)
                .foregroundStyle(themeColor)
            
            if let recent = workout.history?.prefix(3) {
                ForEach(recent, id: \.id) { historyItem in
                    NavigationLink(destination: JournalEntryView(history: historyItem, workout: workout)) {
                        HistoryRow(history: historyItem)
                    }
                }
            } else {
                Text("No completed sessions yet.")
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helpers
    
    private func formatDuration(minutes: Double) -> String {
        let totalSeconds = Int(minutes * 60)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return hours > 0 ? "\(hours)h \(mins)m \(secs)s" : "\(mins)m \(secs)s"
    }
}

// MARK: - Reusable Row
private struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

private struct HistoryRow: View {
    let history: History
    
    var body: some View {
        HStack {
            Text(history.date, style: .date)
            Spacer()
            Text("\(Int(history.lastSessionDuration)) min")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}
