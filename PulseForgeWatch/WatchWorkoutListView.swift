//
//  WatchWorkoutListView.swift
//  PulseForge watchOS
//
//  Created by Joseph DeWeese on 3/1/26.
//
//  Displays workouts synced from iPhone via shared SwiftData store.
//  Tapping a workout navigates directly to the workout session.
//

import SwiftUI
import SwiftData

struct WatchWorkoutListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorManager.self) private var errorManager
    
    // MARK: - Query
    
    @Query(sort: \Workout.dateCreated, order: .reverse)
    private var workouts: [Workout]
    
    // MARK: - Theme
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    private var themeColor: Color { Color(hex: selectedThemeColorData) ?? .blue }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    emptyState
                } else {
                    workoutList
                }
            }
            .navigationTitle("Workouts")
        }
    }
    
    // MARK: - Workout List
    
    private var workoutList: some View {
        List(workouts) { workout in
            NavigationLink(destination: WatchWorkoutSessionView(workout: workout)) {
                WatchWorkoutRow(workout: workout, themeColor: themeColor)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.darkGray).opacity(0.3))
            )
        }
        .listStyle(.carousel)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("No Workouts")
                .font(.headline)
            
            Text("Create workouts on your iPhone to get started.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Watch Workout Row

private struct WatchWorkoutRow: View {
    
    let workout: Workout
    let themeColor: Color
    
    private var accent: Color {
        workout.category?.categoryColor.color ?? Color(.systemGray3)
    }
    
    private var exerciseCount: Int {
        workout.exercises?.count ?? 0
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Category color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(accent)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(workout.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                
                // Category + stats
                HStack(spacing: 6) {
                    if let symbol = workout.category?.symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(accent)
                    }
                    
                    Text("\(exerciseCount) ex")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    if workout.roundsEnabled && workout.roundsQuantity > 1 {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("\(workout.roundsQuantity)R")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(lastSessionTime)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(themeColor)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout: \(workout.title), \(exerciseCount) exercises")
        .accessibilityHint("Double-tap to start workout session")
    }
    
    private var lastSessionTime: String {
        let duration = workout.lastSessionDuration > 0
            ? workout.lastSessionDuration
            : (workout.history ?? [])
                .sorted { $0.date > $1.date }
                .first(where: { $0.lastSessionDuration > 0 })
                .map(\.lastSessionDuration)
        
        guard let d = duration, d > 0 else { return "NEW" }
        
        let totalSeconds = Int((d * 60).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
