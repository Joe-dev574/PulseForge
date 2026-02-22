//
//  WorkoutList.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Workout list view used throughout the app.
//  - Delete action is destructive and confirmed with alert.
//  - Empty state is friendly and guides user to create workouts.
//  - Full VoiceOver accessibility with clear labels and hints.
//  - Consistent theming, dark mode, and dynamic type support.
//

import SwiftUI
import SwiftData

/// Main workout list view with empty state and swipe-to-delete.
/// Uses rounded cards for consistency with the rest of the app.
struct WorkoutList: View {
    
    let workouts: [Workout]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ErrorManager.self) private var errorManager
    
    @State private var workoutToDelete: Workout?
    
    var body: some View {
        Group {
            if workouts.isEmpty {
                EmptyWorkoutState()
            } else {
                workoutList
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workout list")
    }
    
    // MARK: - List
    private var workoutList: some View {
        List {
            ForEach(workouts) { workout in
                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                    WorkoutRow(workout: workout)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                guard let index = indexSet.first else { return }
                workoutToDelete = workouts[index]
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.proBackground)
        .alert("Delete Workout?", isPresented: Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { workoutToDelete = nil }
            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    modelContext.delete(workout)
                    try? modelContext.save()
                }
                workoutToDelete = nil
            }
        } message: {
            Text("This will permanently delete the workout and all its history. This action cannot be undone.")
        }
    }
}

// MARK: - Row
private struct WorkoutRow: View {
    let workout: Workout
    
    var body: some View {
        WorkoutCard(workout: workout)
            .accessibilityElement()
            .accessibilityLabel("Workout: \(workout.title)")
            .accessibilityHint("Double-tap to view details and edit")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Empty State
private struct EmptyWorkoutState: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Workouts Yet")
                    .font(.title2.bold())
                
                Text("Create your first workout to start tracking progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink(destination: AddWorkoutView()) {
                Label("Create New Workout", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.proBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("No workouts yet. Tap to create your first workout.")
    }
}
