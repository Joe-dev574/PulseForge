//
//  WorkoutEditView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Edit screen for existing workouts.
//  - Changes saved locally to SwiftData only.
//  - Full VoiceOver accessibility with clear labels, hints, and dynamic type support.
//  - Consistent theming and dark mode support.
//  - No sensitive data handled; relies on SwiftData for persistence.
//

import SwiftUI
import SwiftData
import Foundation


/// A view for editing the details of an existing workout.
///
/// This view allows users to modify the workout's title, category, rounds, and exercises.
/// Changes are saved to the SwiftData model context upon confirmation.
/// It handles validation and save errors via local alerts.
struct WorkoutEditView: View {
    // MARK: - Environment Properties
    
    /// The SwiftData model context for persisting changes.
    @Environment(\.modelContext) private var context: ModelContext
    
    /// A binding to dismiss the view.
    @Environment(\.dismiss) private var dismiss
    
    /// The current color scheme (light or dark mode).
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Properties
    
    /// The workout being edited.
    let workout: Workout
    
    // MARK: - State Properties
    
    /// The workout title, bound to the text field.
    @State private var title: String
    
    /// The sorted list of exercises for the workout.
    @State private var sortedExercises: [Exercise]
    
    /// The selected category for the workout.
    @State private var selectedCategory: Category?
    
    /// Flag to enable multiple rounds.
    @State private var roundsEnabled: Bool
    
    /// Input string for the number of rounds.
    @State private var roundsQuantityInput: String
    
    /// Flag to show the category picker sheet.
    @State private var showCategoryPicker: Bool = false
    
    /// Flag to present the alert.
    @State private var showAlert: Bool = false
    
    /// Title for alert presentations.
    @State private var alertTitle: String = ""
    
    /// Message for alert presentations.
    @State private var alertMessage: String = ""
    
    // MARK: - Initialization
    
    /// Initializes the view with the workout to edit.
    ///
    /// - Parameter workout: The `Workout` object to edit.
    init(workout: Workout) {
        self.workout = workout
        _title = State(initialValue: workout.title)
        _sortedExercises = State(initialValue: workout.sortedExercises)
        _selectedCategory = State(initialValue: workout.category)
        _roundsEnabled = State(initialValue: workout.roundsEnabled)
        _roundsQuantityInput = State(initialValue: String(workout.roundsQuantity))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Title section.
                Section(header: Text("Title").font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedCategory?.categoryColor.color ?? .secondary)) {
                        TextField("Name of Workout...", text: $title)
                            .font(.system(.body, design: .serif))
                            .textInputAutocapitalization(.words)
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Workout title")
                            .accessibilityHint("Enter the name of the workout")
                    }
                    .accessibilityLabel("Workout title section")
                
                // Category selection section.
                Section(header: Text("Workout Category").font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedCategory?.categoryColor.color ?? .secondary)) {
                        Button(action: { showCategoryPicker = true }) {
                            HStack {
                                if let category = selectedCategory {
                                    Image(systemName: category.symbol)
                                        .foregroundStyle(category.categoryColor.color)
                                        .font(.title3)
                                    Text(category.categoryName)
                                        .foregroundStyle(.primary)
                                } else {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                    Text("Select Category")
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray)
                            }
                            .font(.system(.body, design: .serif))
                        }
                        .accessibilityLabel(selectedCategory?.categoryName ?? "Select workout category")
                        .accessibilityHint("Double-tap to choose a category for the workout")
                        .accessibilityAddTraits(.isButton)
                    }
                    .accessibilityLabel("Workout category section")
                
                // Rounds configuration section.
                Section(header: Text("Rounds").font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedCategory?.categoryColor.color ?? .secondary)) {
                        // Toggle to enable/disable rounds.
                        Toggle("Enable Rounds", isOn: $roundsEnabled)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Enable rounds")
                            .accessibilityHint("Toggle to enable multiple rounds for the workout")
                            .accessibilityValue(roundsEnabled ? "On" : "Off")
                        
                        // Text field for number of rounds, shown if enabled.
                        if roundsEnabled {
                            TextField("Number of Rounds", text: $roundsQuantityInput)
                                .keyboardType(.numberPad)
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(.primary)
                                .accessibilityLabel("Number of rounds")
                                .accessibilityHint("Enter the number of rounds for the workout")
                            // Validate input on change.
                                .onChange(of: roundsQuantityInput) { _, newValue in
                                    if newValue.isEmpty {
                                        workout.roundsQuantity = 1 // Temporary default while typing
                                    } else if let quantity = Int(newValue), quantity > 0 {
                                        workout.roundsQuantity = quantity
                                    } else {
                                        roundsQuantityInput = String(workout.roundsQuantity)
                                    }
                                }
                            // Ensure valid value on submit.
                                .onSubmit {
                                    if roundsQuantityInput.isEmpty || Int(roundsQuantityInput) == nil || Int(roundsQuantityInput)! <= 0 {
                                        roundsQuantityInput = "1"
                                        workout.roundsQuantity = 1
                                    }
                                }
                        }
                    }
                    .accessibilityLabel("Rounds section")
                
                // Exercises list section.
                Section(header: Text("Exercises").font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedCategory?.categoryColor.color ?? .secondary)) {
                        // List of editable exercises.
                        ForEach($sortedExercises) { $exercise in
                            HStack {
                                TextField("Exercise (e.g., Push-ups 10x10)", text: $exercise.name)
                                    .font(.system(.body, design: .serif))
                                    .foregroundStyle(.primary)
                                    .accessibilityLabel("Exercise name")
                                    .accessibilityHint("Enter the name or description of the exercise")
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.gray)
                                    .font(.system(size: 18))
                                    .accessibilityLabel("Reorder exercise")
                                    .accessibilityHint("Drag to reorder this exercise")
                                    .accessibilityAddTraits(.isButton)
                            }
                            .accessibilityElement(children: .contain)
                            // Accessibility action for deletion.
                            .accessibilityAction(named: "Delete") {
                                if let index = sortedExercises.firstIndex(of: exercise) {
                                    sortedExercises.remove(at: index)
                                    updateExerciseOrders()
                                }
                            }
                        }
                        // Support for deleting via swipe.
                        .onDelete { offsets in
                            sortedExercises.remove(atOffsets: offsets)
                            updateExerciseOrders()
                        }
                        // Support for reordering.
                        .onMove { source, destination in
                            moveExercises(from: source, to: destination)
                        }
                        // Button to add a new exercise.
                        Button(action: {
                            let newExercise = Exercise(name: "", order: sortedExercises.count)
                            sortedExercises.append(newExercise)
                        }) {
                            Text("Add Exercise")
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(.blue)
                        }
                        .accessibilityLabel("Add exercise")
                        .accessibilityHint("Double-tap to add a new exercise to the workout")
                        .accessibilityAddTraits(.isButton)
                    }
                    .accessibilityLabel("Exercises section")
            }
            .navigationTitle("Edit Workout")
            .scrollContentBackground(.hidden)
            .background(Color.proBackground)
            .accessibilityLabel("Edit workout form")
            .accessibilityHint("Form to edit workout details, including title, category, rounds, and exercises")
            // Toolbar with save button.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { save() }) {
                        Text("Save")
                            .font(.system(.body).weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(workout.category?.categoryColor.color ?? .blue)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save workout")
                    .accessibilityHint(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Disabled, enter a workout title to enable" : "Double-tap to save changes to the workout")
                    .accessibilityValue(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Disabled" : "Enabled")
                }
            }
            // Sheet for selecting category.
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPicker(selectedCategory: $selectedCategory)
                    .accessibilityLabel("Category picker")
                    .accessibilityHint("Select a category for the workout")
            }
            // Local alert for validation, success, and errors.
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Moves exercises in the list and updates their orders.
    ///
    /// - Parameters:
    ///   - source: The source index set for moving.
    ///   - destination: The destination index.
    private func moveExercises(from source: IndexSet, to destination: Int) {
        sortedExercises.move(fromOffsets: source, toOffset: destination)
        updateExerciseOrders()
    }
    
    /// Updates the order property of each exercise based on their current position.
    private func updateExerciseOrders() {
        for (index, exercise) in sortedExercises.enumerated() {
            exercise.order = index
        }
    }
    
    /// Saves changes to the workout and handles validation and errors.
    ///
    /// Validates the title, filters valid exercises, updates the model, and saves the context.
    /// Presents alerts for feedback and dismisses the view on success after a delay.
    @MainActor
    private func save() {
        // Validate title is not empty.
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertTitle = "Validation Error"
            alertMessage = "Workout title cannot be empty."
            showAlert = true
            return
        }
        
        // Update workout properties.
        workout.title = title
        workout.category = selectedCategory
        workout.roundsEnabled = roundsEnabled
        workout.roundsQuantity = max(1, Int(roundsQuantityInput) ?? 1)
        
        // Filter out empty exercises and update orders.
        let validExercises = sortedExercises.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for (index, exercise) in validExercises.enumerated() {
            exercise.order = index
        }
        workout.exercises = validExercises
        
        do {
            try context.save()
            alertTitle = "Workout Saved"
            alertMessage = "Your workout '\(workout.title)' has been successfully updated."
            showAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        } catch {
            alertTitle = "Save Error"
            alertMessage = "Failed to save workout: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Extensions

/// Extension for Optional to provide a bound value.
extension Optional where Wrapped: Hashable {
    /// A bound optional value for use in bindings.
    var bound: Wrapped? {
        get { self }
        set { self = newValue }
    }
}
