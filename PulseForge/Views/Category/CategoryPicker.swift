//
//  CategoryPicker.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Simple category selection view used during workout creation.
//  - No HealthKit or subscription data accessed here.
//  - Full VoiceOver accessibility with clear labels and hints.
//  - Dynamic type and high contrast support.
//  - Consistent with app-wide theming and dark mode.
//

import SwiftUI
import SwiftData

/// Category selection screen for assigning a category to a workout.
/// Uses a responsive grid layout with visual category cards.
struct CategoryPicker: View {
    
    // MARK: - Binding
    @Binding var selectedCategory: Category?
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Query
    @Query(sort: \Category.categoryName, order: .forward) private var categories: [Category]
    
    // MARK: - State / Theme
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    if categories.isEmpty {
                        ContentUnavailableView(
                            "No Categories",
                            systemImage: "folder.badge.plus",
                            description: Text("Create a category first in Settings.")
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(categories) { category in
                                CategoryCell(
                                    category: category,
                                    isSelected: selectedCategory?.id == category.id
                                )
                                .onTapGesture {
                                    selectedCategory = category
                                    dismiss()
                                }
                            }
                        }
                        .padding(16)
                    }
                }
                .navigationTitle("Select Category")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
}

// MARK: - Category Cell

private struct CategoryCell: View {
    let category: Category
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.system(size: 32))
                .foregroundStyle(category.categoryColor.color)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(category.categoryColor.color.opacity(0.15))
                )
            
            Text(category.categoryName)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? category.categoryColor.color.opacity(0.2) : Color(.systemBackground).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? category.categoryColor.color : .clear, lineWidth: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.categoryName) category")
        .accessibilityHint(isSelected ? "Currently selected" : "Double-tap to select this category")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
