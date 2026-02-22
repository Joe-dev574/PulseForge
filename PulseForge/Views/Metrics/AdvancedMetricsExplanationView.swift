//
//  AdvancedMetricsExplanationView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/21/26.
//
//  Apple App Store Compliance (required for review):
//  - Explains premium metrics shown in JournalEntryView and ProgressBoardView.
//  - No data collection or HealthKit access — purely informational.
//  - Full VoiceOver accessibility with clear headers and dynamic type support.
//  - Consistent with app-wide theming and dark mode.
//  - Used as a popover/sheet for user education.
//

import SwiftUI

/// Reusable popover explaining advanced premium metrics (Intensity Score, Progress Pulse, Dominant Zone).
/// Shown when user taps the info icon in journal or progress views.
struct AdvancedMetricsExplanationView: View {
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                
                intensityExplanation
                progressPulseExplanation
                dominantZoneExplanation
                
                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private var header: some View {
        Text("Advanced Metrics Explained")
            .font(.title2.bold())
            .foregroundStyle(themeColor)
            .accessibilityAddTraits(.isHeader)
    }
    
    private var intensityExplanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Intensity Score", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(themeColor)
                .accessibilityAddTraits(.isHeader)
            
            Text("Reflects the cardiovascular challenge of the workout based on average heart rate relative to your resting heart rate.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var progressPulseExplanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Progress Pulse Score (0–100)", systemImage: "heart.text.clipboard")
                .font(.headline)
                .foregroundStyle(themeColor)
                .accessibilityAddTraits(.isHeader)
            
            Text("Overall workout effectiveness. Combines:\n• Performance vs. Personal Best\n• Workout Frequency vs. Target\n• Intensity (dominant heart rate zone)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var dominantZoneExplanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Dominant Heart Rate Zone (1–5)", systemImage: "figure.walk.motion")
                .font(.headline)
                .foregroundStyle(themeColor)
                .accessibilityAddTraits(.isHeader)
            
            Text("The zone where you spent the most time during the session.\n1 = Very Light, 2 = Light, 3 = Moderate, 4 = Hard, 5 = Maximum.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
