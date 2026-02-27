//
//  JournalEntryView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance:
//  - Split times shown in exact performance order (including rounds)
//  - Premium metrics gated behind subscription
//  - Keyboard never blocks Save button (Save is in navigation bar)
//  - Full accessibility + dynamic type support
//

import SwiftUI
import SwiftData
import OSLog

struct JournalEntryView: View {
    
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ErrorManager.self) private var errorManager
    @Environment(PurchaseManager.self) private var purchaseManager
    
    // MARK: - Properties
    @Bindable var history: History
    let workout: Workout
    
    // MARK: - State
    @State private var journalText: String = ""
    @FocusState private var isJournalFocused: Bool
    @State private var showMetricsInfoPopover: Bool = false
    
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
            .scrollDismissesKeyboard(.interactively)   // ← Swipe down to hide keyboard
        }
        .navigationTitle("Journal Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveJournalEntry()
                    isJournalFocused = false   // dismiss keyboard
                }
                .fontWeight(.semibold)
                .disabled(journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && history.notes == nil)
            }
        }
        .onAppear {
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
                
                let sortedSplits = splits.sorted { $0.order < $1.order }
                let baseCount = workout.sortedExercises.count
                let hasRounds = workout.roundsEnabled && workout.roundsQuantity > 1
                
                ForEach(sortedSplits) { split in
                    if let exercise = workout.effectiveExercises[safe: split.order] {
                        let roundNumber = hasRounds ? (split.order / baseCount + 1) : nil
                        
                        HStack {
                            Image(systemName: "timer")
                                .foregroundStyle(workout.category?.categoryColor.color ?? .blue)
                                .accessibilityHidden(true)
                            
                            Text(roundNumber != nil
                                 ? "Round \(roundNumber!): \(exercise.name)"
                                 : exercise.name)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text(formatTime(seconds: split.durationInSeconds))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            roundNumber != nil
                            ? "Round \(roundNumber!), \(exercise.name), Split Time: \(formatTime(seconds: split.durationInSeconds))"
                            : "\(exercise.name), Split Time: \(formatTime(seconds: split.durationInSeconds))"
                        )
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
        if history.intensityScore != nil || history.progressPulseScore != nil || history.dominantZone != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("Advanced Metrics")
                    .font(.headline)
                
                if let intensity = history.intensityScore {
                    MetricRow(icon: "flame.fill", title: "Intensity Score", value: "\(Int(intensity))%")
                }
                if let pulse = history.progressPulseScore, purchaseManager.isSubscribed {
                    MetricRow(icon: "heart.text.clipboard", title: "Progress Pulse", value: "\(Int(pulse))")
                }
                if let zone = history.dominantZone {
                    MetricRow(icon: "figure.walk.motion", title: "Dominant Zone", value: "Zone \(zone)")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if purchaseManager.isSubscribed {
            Text("No metrics available for this session yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        }
    }
    
    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Journal")
                .font(.headline)
            
            TextEditor(text: $journalText)
                .frame(minHeight: 180)           // taller for comfortable typing
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
    
    private func saveJournalEntry() {
        history.notes = journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : journalText
        do {
            try modelContext.save()
            logger.info("Journal entry saved")
        } catch {
            errorManager.present(
                title: "Save Failed",
                message: "Could not save journal entry. Please try again."
            )
        }
    }
}

// MARK: - Reusable Metric Row
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

// MARK: - Safe Subscript
private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
