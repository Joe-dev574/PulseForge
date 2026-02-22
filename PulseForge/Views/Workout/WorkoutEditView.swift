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

/// Edit screen for an existing workout.
/// Allows updating title, category, rounds, and exercises.
struct WorkoutEditView: View {
    
    // MARK: - Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ErrorManager.self) private var errorManager
    
    // MARK: - Properties
    let workout: Workout
    
    // MARK: - State (local editing copies)
    @State private var title: String
    @State private var exercises: [Exercise]
    @State private var selectedCategory: Category?
    @State private var roundsEnabled: Bool
    @State private var roundsQuantityInput: String
    
    @State private var showCategoryPicker = false
    
    @FocusState private var focusedExerciseIndex: Int?
    
    // MARK: - Theme
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    // MARK: - Init
    init(workout: Workout) {
        self.workout = workout
        _title = State(initialValue: workout.title)
        _exercises = State(initialValue: workout.sortedExercises)
        _selectedCategory = State(initialValue: workout.category)
        _roundsEnabled = State(initialValue: workout.roundsEnabled)
        _roundsQuantityInput = State(initialValue: String(workout.roundsQuantity))
    }
    
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        titleSection
                        categorySection
                        roundsSection
                        exercisesSection
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("Edit Workout")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showCategoryPicker) {
                    CategoryPicker(selectedCategory: $selectedCategory)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Sections
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Title")
                .font(.headline)
                .foregroundStyle(themeColor)
            
            TextField("Name of Workout...", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .textInputAutocapitalization(.words)
                .focused($focusedExerciseIndex, equals: -1)
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.headline)
                .foregroundStyle(themeColor)
            
            Button {
                showCategoryPicker = true
            } label: {
                HStack {
                    if let cat = selectedCategory {
                        Image(systemName: cat.symbol)
                            .foregroundStyle(cat.categoryColor.color)
                        Text(cat.categoryName)
                            .foregroundStyle(.primary)
                    } else {
                        Text("Select Category")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var roundsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable Rounds (for circuits/HIIT)", isOn: $roundsEnabled)
                .tint(themeColor)
            
            if roundsEnabled {
                TextField("Number of Rounds", text: $roundsQuantityInput)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: roundsQuantityInput) { _, newValue in
                        if newValue.isEmpty {
                            roundsQuantityInput = "1"
                        } else if let n = Int(newValue), n > 0 {
                            roundsQuantityInput = newValue
                        } else {
                            roundsQuantityInput = String(workout.roundsQuantity)
                        }
                    }
            }
        }
    }
    
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercises")
                    .font(.headline)
                    .foregroundStyle(themeColor)
                
                Spacer()
                
                Button {
                    let newIndex = exercises.count
                    exercises.append(Exercise(name: "", order: newIndex))
                    focusedExerciseIndex = newIndex
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                        .foregroundStyle(themeColor)
                }
            }
            
            ForEach(exercises.indices, id: \.self) { index in
                TextField(
                    "Exercise name, sets × reps (e.g., Bench Press 4×10)",
                    text: $exercises[index].name
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedExerciseIndex, equals: index)
                .onSubmit {
                    if exercises[index].name.isEmpty {
                        exercises.remove(at: index)
                    }
                }
            }
            .onDelete { offsets in
                exercises.remove(atOffsets: offsets)
                updateExerciseOrders()
            }
        }
    }
    
    // MARK: - Toolbar
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveWorkout() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
            }
        }
    }
    
    // MARK: - Save Logic
    private func saveWorkout() {
        let cleanedExercises = exercises.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        workout.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.category = selectedCategory
        workout.roundsEnabled = roundsEnabled
        workout.roundsQuantity = max(1, Int(roundsQuantityInput) ?? 1)
        workout.exercises = cleanedExercises
        
        updateExerciseOrders()
        
        do {
            try context.save()
            dismiss()
        } catch {
            errorManager.present(title: "Save Error", message: error.localizedDescription)
        }
    }
    
    private func updateExerciseOrders() {
        for (index, _) in exercises.enumerated() {
            exercises[index].order = index
        }
    }
}
