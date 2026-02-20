//
//  JournalEntryView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/20/26.
//

import SwiftUI
import SwiftData


/// A SwiftUI view that displays a detailed journal entry for a workout history item.
/// This view includes workout title, date, split times, total time, advanced metrics with explanations,
/// and an editable journal section. It ensures accessibility compliance by providing appropriate labels,
/// hints, combined elements for VoiceOver, and support for dynamic type sizes.
struct JournalEntryView: View {
    // MARK: - Properties
    
    /// The bindable history object containing workout session data.
    @Bindable var history: History
    
    /// The associated workout object.
    let workout: Workout
    
    /// Environment variable for the model context to save changes.
    @Environment(\.modelContext) private var modelContext
    
    /// Environment variable for error management.
    @Environment(ErrorManager.self) private var errorManager
    
    /// The selected theme color stored in AppStorage.
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#929000"
    
    /// Computed property for the theme color, defaulting to blue if hex conversion fails.
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    /// Computed property for the category color, falling back to themeColor if not available.
    private var categoryColor: Color {
        workout.category?.categoryColor.color ?? themeColor
    }
    
    /// State variable for the journal text editor content.
    @State private var journalText: String = ""
    
    /// Focus state for the journal text editor.
    @FocusState private var isJournalEditorFocused: Bool
    
    /// State variable to control the visibility of the metrics info popover.
    @State private var showMetricsInfoPopover: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea(edges: .all)
            VStack(alignment: .leading, spacing: 10) {
                headerSection
                if let splitTimes = history.splitTimes, !splitTimes.isEmpty {
                    splitTimesSection(splitTimes: splitTimes)
                }
                totalTimeSection
                metricsSection
                journalSection
            }
            .fontDesign(.serif)
            .padding()
            .background(Material.thin)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            // Support dynamic type sizes for accessibility.
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Journal entry view")
        }
    }
    
    // MARK: - Subviews
    
    /// The header section displaying workout title, date, and category symbol.
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(workout.title)
                    .font(.headline.bold())
                    .foregroundStyle(categoryColor)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                Text(history.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            Spacer()
            if let categorySymbol = workout.category?.symbol {
                Image(systemName: categorySymbol)
                    .font(.title2)
                    .foregroundStyle(categoryColor.opacity(0.7))
                    .accessibilityLabel("Category: \(workout.category?.categoryName ?? "None")")
            }
        }
        .padding(.bottom, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout: \(workout.title), Date: \(history.date, style: .date)")
        
        Divider()
            .accessibilityHidden(true)
    }
    
    /// Section displaying split times for exercises, including rounds if applicable.
    @ViewBuilder
    private func splitTimesSection(splitTimes: [SplitTime]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Split Times")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            
            ForEach(splitTimes.indices, id: \.self) { index in
                let split = splitTimes[index]
                let exerciseIndex = split.order
                if exerciseIndex < workout.sortedExercises.count,
                   let exercise = workout.sortedExercises[safe: exerciseIndex] {
                    let roundNumber = workout.roundsEnabled && workout.roundsQuantity > 1 ? (index / workout.sortedExercises.count + 1) : nil
                    HStack {
                        Image(systemName: "timer")
                            .foregroundStyle(categoryColor.opacity(0.8))
                            .accessibilityHidden(true) // Decorative icon.
                        Text(roundNumber != nil ? "Round \(roundNumber!): \(exercise.name)" : exercise.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatTime(value: split.durationInSeconds, isSeconds: true))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("splitTime_\(index)")
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(roundNumber != nil ? "Round \(roundNumber!), \(exercise.name), Split Time: \(formatTime(value: split.durationInSeconds, isSeconds: true))" : "\(exercise.name), Split Time: \(formatTime(value: split.durationInSeconds, isSeconds: true))")
                }
            }
        }
        .padding(.bottom, 5)
        
        Divider()
            .accessibilityHidden(true)
    }
    
    /// Section displaying the total workout time.
    @ViewBuilder
    private var totalTimeSection: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundStyle(categoryColor)
                .accessibilityHidden(true) // Decorative icon.
            Text("Total Time:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Spacer()
            Text(formatTime(value: history.lastSessionDuration))
                .font(.headline.monospacedDigit())
                .fontWeight(.medium)
                .foregroundStyle(categoryColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total Time: \(formatTime(value: history.lastSessionDuration))")
    }
    
    /// Section for advanced metrics or a message if metrics are unavailable.
    @ViewBuilder
    private var metricsSection: some View {
        if history.intensityScore != nil || history.progressPulseScore != nil || history.dominantZone != nil {
            advancedMetricsSection
        } else {
            Divider()
                .accessibilityHidden(true)
                .padding(.vertical, 5)
            Text("No HealthKit metrics available. Authorize HealthKit in Settings to view advanced metrics.")
                .font(.caption)
                .foregroundStyle(.primary)
                .accessibilityLabel("No HealthKit metrics available. Authorize HealthKit in Settings.")
        }
    }
    
    /// Detailed advanced metrics display with popover explanation.
    @ViewBuilder
    private var advancedMetricsSection: some View {
        Divider()
            .accessibilityHidden(true)
            .padding(.vertical, 5)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Advanced Metrics")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                Button {
                    showMetricsInfoPopover = true
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(categoryColor)
                }
                .accessibilityLabel("Show metrics explanation")
                .accessibilityHint("Opens a dialog explaining intensity, progress pulse, and heart rate zones")
                .accessibilityAddTraits(.isButton)
            }
            .padding(.bottom, 2)
            
            if let intensity = history.intensityScore {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(categoryColor.opacity(0.8))
                        .accessibilityHidden(true) // Decorative icon.
                    Text("Intensity Score:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(String(format: "%.0f", intensity))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Intensity Score: \(Int(intensity)) percent")
            }
            if let pulse = history.progressPulseScore, PurchaseManager.shared.isSubscribed {
                HStack {
                    Image(systemName: "heart.text.clipboard.fill")
                        .foregroundStyle(categoryColor.opacity(0.8))
                        .accessibilityHidden(true) // Decorative icon.
                    Text("Progress Pulse:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(String(format: "%.0f", pulse))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Progress Pulse Score: \(Int(pulse))")
            }
            if let zone = history.dominantZone, let description = zoneDescription(for: zone) {
                HStack {
                    Image(systemName: "figure.walk.motion")
                        .foregroundStyle(categoryColor.opacity(0.8))
                        .accessibilityHidden(true) // Decorative icon.
                    Text("Dominant Zone:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(zone) (\(description))")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Dominant Heart Rate Zone: \(zone), \(description)")
            }
        }
        .popover(isPresented: $showMetricsInfoPopover) {
            AdvancedMetricsExplanationView()
                .presentationCompactAdaptation(.popover)
            .accessibilityAddTraits(.isModal)
        }
    }
    
    /// The journal section with editable text editor and save button.
    @ViewBuilder
    private var journalSection: some View {
        Divider()
            .accessibilityHidden(true)
            .padding(.vertical, 5)
        
        VStack(alignment: .leading) {
            Text("Workout Journal")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $journalText)
                    .frame(height: 100)
                    .font(.body)
                    .focused($isJournalEditorFocused)
                    .accessibilityLabel("Workout journal")
                    .accessibilityHint("Enter notes about your workout session")
                    .onAppear {
                        journalText = history.notes ?? ""
                    }
                
                if journalText.isEmpty {
                    Text("Add comments, details, or notes...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)  // Ensures taps pass through to the TextEditor
                        .accessibilityHidden(true) // Placeholder is visual only.
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            if journalText != (history.notes ?? "") || isJournalEditorFocused {
                Button(action: {
                    saveJournalEntry()
                    isJournalEditorFocused = false
                }) {
                    Text("Save Journal")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(categoryColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 5)
                .accessibilityLabel("Save journal entry")
                .accessibilityHint("Saves your workout journal notes")
                .accessibilityAddTraits(.isButton)
            }
        }
        .fontDesign(.serif)
    }
    
    // MARK: - Private Methods
    
    /// Saves the journal entry to the history object and persists changes.
    private func saveJournalEntry() {
        history.notes = journalText.isEmpty ? nil : journalText
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            errorManager.present(
                title: "Journal Save Failed",
                message: "Could not save your journal entry. Please try again."
            )
        }
    }
    
    /// Formats a time value into a string representation.
    /// - Parameters:
    ///   - value: The time value to format.
    ///   - isSeconds: Indicates if the value is in seconds (true) or minutes (false).
    /// - Returns: A formatted string in hours:minutes:seconds.milliseconds or minutes:seconds.milliseconds.
    func formatTime(value: Double, isSeconds: Bool = false) -> String {
        let totalSeconds = isSeconds ? value : value * 60
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        let milliseconds = Int((totalSeconds - floor(totalSeconds)) * 100)
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
        }
    }
    
    /// Converts a heart rate zone integer to a descriptive string.
    /// - Parameter zone: The heart rate zone number (optional).
    /// - Returns: A string describing the zone or nil if zone is nil.
    private func zoneDescription(for zone: Int?) -> String? {
        guard let zone else { return nil }
        switch zone {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "Unknown"
        }
    }
}

/// A reusable view explaining advanced metrics.
struct AdvancedMetricsExplanationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("Advanced Metrics Explained")
                    .font(.title2.bold())
                    .padding(.bottom, 5)
                    .accessibilityAddTraits(.isHeader)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Intensity Score")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Reflects the cardiovascular challenge based on heart rate during the workout relative to your resting heart rate. Calculated using average workout heart rate and resting heart rate.")
                        .font(.subheadline)
                }
                Divider()
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Progress Pulse Score (0-100)")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Indicates workout effectiveness. Considers:\n• Performance vs. Personal Best (time/duration)\n• Workout Frequency (vs. target per week)\n• Intensity (dominant heart rate zone achieved).")
                        .font(.subheadline)
                }
                Divider()
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dominant Heart Rate Zone (1-5)")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("The zone (Very Light, Light, Moderate, Hard, Maximum) where you spent the most time. Calculated by analyzing heart rate samples against your max heart rate (estimated if not set).")
                        .font(.subheadline)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Extensions

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
