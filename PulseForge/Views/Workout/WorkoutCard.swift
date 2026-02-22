//
//  WorkoutCard.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Workout summary card used in lists and navigation.
//  - Displays category color, title, exercise count, rounds (if enabled), and last session time.
//  - Full VoiceOver accessibility with combined elements, labels, hints, and button traits.
//  - Dynamic type support and high contrast compatibility.
//  - No sensitive data; relies on SwiftData for local persistence.
//

import SwiftUI
import SwiftData

/// A clean, tappable card summarizing a workout for use in lists.
/// Navigates to WorkoutDetailView on tap.
struct WorkoutCard: View {
    
    let workout: Workout
    
    @Environment(ErrorManager.self) private var errorManager
    
    private var exerciseCount: Int {
        workout.exercises?.count ?? 0
    }
    
    var body: some View {
        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                infoRow
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(workout.category?.categoryColor.color.opacity(0.3) ?? .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout: \(workout.title), \(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises")\(workout.roundsEnabled && workout.roundsQuantity > 1 ? ", \(workout.roundsQuantity) rounds" : "")")
        .accessibilityHint("Tap to view details and edit")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Subviews
    
    private var headerRow: some View {
        HStack(spacing: 12) {
            if let category = workout.category {
                Image(systemName: category.symbol)
                    .font(.title2)
                    .foregroundStyle(category.categoryColor.color)
                    .frame(width: 36, height: 36)
            } else {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            
            Text(workout.title)
                .font(.headline)
                .fontDesign(.serif)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(2)
            
            Spacer()
        }
    }
    
    private var infoRow: some View {
        HStack(spacing: 16) {
            Label {
                Text("\(exerciseCount) \(exerciseCount == 1 ? "Exercise" : "Exercises")")
            } icon: {
                Image(systemName: "list.bullet")
            }
            
            if workout.roundsEnabled && workout.roundsQuantity > 1 {
                Label {
                    Text("\(workout.roundsQuantity) Rounds")
                } icon: {
                    Image(systemName: "repeat")
                }
            }
            
            Spacer()
            
            Text(lastSessionTime)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    // MARK: - Helpers
    
    private var lastSessionTime: String {
        guard workout.lastSessionDuration > 0 else { return "—" }
        let minutes = Int(workout.lastSessionDuration)
        let seconds = Int((workout.lastSessionDuration - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}
