//
//  JournalEntryView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - All advanced metrics are fetched from MetricsManager (single source of truth).
//  - Premium metrics (Intensity Score, Progress Pulse, Dominant Zone) are gated behind subscription.
//  - HealthKit data is displayed on-device only.
//  - Full VoiceOver accessibility, dynamic type, and Reduce Motion support.
//  - No data leaves the device except private iCloud (premium only).
//

import SwiftUI
import SwiftData
import OSLog

/// Detailed journal view for a completed workout session.
/// Displays split times, total time, advanced metrics (premium), and editable notes.
struct JournalEntryView: View {
    
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ErrorManager.self) private var errorManager
    @Environment(MetricsManager.self) private var metricsManager
    @Environment(PurchaseManager.self) private var purchaseManager
    
    // MARK: - Properties
    @Bindable var history: History
    let workout: Workout
    
    // MARK: - State
    @State private var journalText: String = ""
    @FocusState private var isJournalFocused: Bool
    @State private var showMetricsExplanation = false
    @State private var metrics: WorkoutMetrics?
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.tnt.PulseForge", category: "JournalEntryView")
    
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    splitTimesSection
                    totalTimeSection
                    metricsSection
                    journalSection
                }
                .padding()
            }
        }
        .navigationTitle("Journal Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            await loadMetrics()
            journalText = history.notes ?? ""
        }
        .onChange(of: journalText) { _, newValue in
            history.notes = newValue.isEmpty ? nil : newValue
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.title)
                .font(.title2.bold())
                .foregroundStyle(workout.category?.categoryColor.color ?? .blue)
            
            Text(history.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout: \(workout.title), Date: \(history.date, style: .date)")
    }
    
    @ViewBuilder
    private var splitTimesSection: some View {
        if let splits = history.splitTimes, !splits.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Split Times")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                ForEach(Array(splits.enumerated()), id: \.offset) { index, split in
                    let exercise = workout.sortedExercises[split.order]
                    HStack {
                        Text(exercise.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatTime(seconds: split.durationInSeconds))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var totalTimeSection: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundStyle(.green)
            Text("Total Time")
                .font(.headline)
            Spacer()
            Text(formatTime(seconds: history.lastSessionDuration * 60))
                .font(.title3.bold().monospacedDigit())
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private var metricsSection: some View {
        if purchaseManager.isSubscribed {
            if let m = metrics {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Advanced Metrics")
                        .font(.headline)
                    
                    if let intensity = m.intensityScore {
                        MetricRow(icon: "flame.fill", title: "Intensity Score", value: "\(Int(intensity))%")
                    }
                    if let pulse = m.progressPulseScore {
                        MetricRow(icon: "heart.text.clipboard", title: "Progress Pulse", value: "\(Int(pulse))")
                    }
                    if let zone = m.dominantZone {
                        MetricRow(icon: "figure.walk.motion", title: "Dominant Zone", value: "Zone \(zone)")
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        } else {
            Text("Upgrade to Premium to see advanced metrics")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
                .padding(.horizontal)
        }
    }
    
    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Journal")
                .font(.headline)
            
            TextEditor(text: $journalText)
                .frame(minHeight: 120)
                .font(.body)
                .focused($isJournalFocused)
                .padding(8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Helpers
    
    private func loadMetrics() async {
        metrics = await metricsManager.fetchMetrics(for: workout, history: history)
    }
    
    private func formatTime(seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

// MARK: - Reusable Row
private struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.green)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}
