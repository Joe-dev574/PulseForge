//
//  AddWorkoutView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Workout creation screen with title, category, rounds, and dynamic exercises.
//  - Data saved locally to SwiftData only.
//  - Full VoiceOver accessibility with clear labels, hints, and dynamic type support.
//  - Consistent theming and dark mode support.
//  - No sensitive data handled; relies on SwiftData for persistence.
//

import SwiftUI
import SwiftData

/// View for creating a new workout with title, category, optional rounds, and dynamic exercises.
struct AddWorkoutView: View {

    // MARK: - Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @Environment(ErrorManager.self) private var errorManager

    // MARK: - State
    @State private var title:               String     = ""
    @State private var exercises:           [Exercise] = []
    @State private var selectedCategory:    Category?  = nil
    @State private var roundsEnabled:       Bool       = false
    @State private var roundsCount:         Int        = 3
    @State private var showCategoryPicker:  Bool       = false

    @FocusState private var focusedExerciseIndex: Int?

    // MARK: - Theme
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"

    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        titleSection
                        categorySection
                        roundsSection
                        exercisesSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("New Workout")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showCategoryPicker) {
                    CategoryPicker(selectedCategory: $selectedCategory)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("WORKOUT TITLE")
                .foregroundStyle(themeColor)

            VStack(alignment: .leading, spacing: 6) {
                TextField("e.g., Upper Body A", text: $title)
                    .font(.title3.weight(.medium))
                    .textInputAutocapitalization(.words)
                    .focused($focusedExerciseIndex, equals: -1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Workout title")
                    .accessibilityHint("Enter a name for your new workout")

                if !title.isEmpty {
                    Text("\(title.trimmingCharacters(in: .whitespacesAndNewlines).count) characters")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("CATEGORY")
                .foregroundStyle(themeColor)

            Button {
                showCategoryPicker = true
            } label: {
                HStack(spacing: 14) {
                    if let cat = selectedCategory {
                        ZStack {
                            Circle()
                                .fill(cat.categoryColor.color.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: cat.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(cat.categoryColor.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.categoryName)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Tap to change")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: 40, height: 40)
                            Image(systemName: "tag")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                        Text("Select a category")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedCategory.map { "Category: \($0.categoryName). Tap to change" } ?? "Select a category")
            .accessibilityHint("Opens the category picker")
        }
    }

    // MARK: - Rounds Section

    private var roundsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("ROUNDS")
                .foregroundStyle(themeColor)
            VStack(spacing: 0) {
                Toggle(isOn: $roundsEnabled) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(roundsEnabled ? themeColor : .secondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Rounds")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("For circuits, HIIT, and supersets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(themeColor)
                .padding(14)

                if roundsEnabled {
                    Divider()
                        .padding(.horizontal, 14)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Number of Rounds")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Applies to all exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Stepper(value: $roundsCount, in: 1...99) {
                            Text("\(roundsCount)")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(themeColor)
                                .frame(minWidth: 36, alignment: .trailing)
                        }
                        .accessibilityLabel("Rounds")
                        .accessibilityValue("\(roundsCount) rounds")
                    }
                    .padding(14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .animation(.easeInOut(duration: 0.2), value: roundsEnabled)
        }
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(themeColor)
                    .frame(width: 3, height: 13)
                    .accessibilityHidden(true)
                Text("EXERCISES")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(themeColor)
                    .tracking(2)
                Spacer()
                Button {
                    let newIndex = exercises.count
                    exercises.append(Exercise(name: "", order: newIndex))
                    focusedExerciseIndex = newIndex
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(themeColor)
                }
                .accessibilityLabel("Add exercise")
            }
            .accessibilityAddTraits(.isHeader)

            if exercises.isEmpty {
                exerciseEmptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(exercises.indices, id: \.self) { index in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(themeColor)
                                    .frame(width: 26, height: 26)
                                    .background(themeColor.opacity(0.12))
                                    .clipShape(Circle())
                                    .accessibilityHidden(true)

                                TextField(
                                    "Exercise, sets × reps (e.g., Bench Press 4×10)",
                                    text: $exercises[index].name
                                )
                                .font(.subheadline)
                                .focused($focusedExerciseIndex, equals: index)
                                .onSubmit {
                                    if exercises[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        exercises.remove(at: index)
                                        updateExerciseOrders()
                                    }
                                }
                                .accessibilityLabel("Exercise \(index + 1)")
                                .accessibilityHint("Enter exercise name, sets and reps. Submit to remove if empty.")

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        exercises.remove(at: index)
                                        updateExerciseOrders()
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color(.systemFill))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove exercise \(index + 1)")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)

                            if index < exercises.count - 1 {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var exerciseEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(themeColor.opacity(0.4))
            Text("No exercises yet")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Tap + Add to build your exercise list")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No exercises added. Tap Add Exercise to get started.")
    }

    // MARK: - Toolbar

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.secondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveWorkout() }
                    .disabled(isSaveDisabled)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSaveDisabled ? .secondary : themeColor)
            }
        }
    }

    // MARK: - Save Logic

    private func saveWorkout() {
        let cleanedExercises = exercises.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let workout = Workout(
            title:          title.trimmingCharacters(in: .whitespacesAndNewlines),
            exercises:      cleanedExercises,
            category:       selectedCategory,
            roundsEnabled:  roundsEnabled,
            roundsQuantity: roundsCount
        )

        context.insert(workout)

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

// MARK: - SectionLabel

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 3, height: 13)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
        }
        .accessibilityAddTraits(.isHeader)
    }
}
