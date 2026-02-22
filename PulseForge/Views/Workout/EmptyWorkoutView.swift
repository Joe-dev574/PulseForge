//
//  EmptyWorkoutView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Empty state shown when no workouts exist in the list.
//  - Encourages user to create their first workout (core free feature).
//  - Full VoiceOver accessibility with clear labels and hints.
//  - Respects Reduce Motion preference.
//  - Dynamic type and high contrast support.
//  - Consistent with app-wide dark/pro theme.
//

import SwiftUI

/// Empty state view displayed when the user has no workouts yet.
/// Guides the user to create their first workout with a friendly, accessible design.
struct EmptyWorkoutView: View {
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(themeColor.opacity(0.7))
                    .symbolEffect(.pulse, isActive: isAnimating && !UIAccessibility.isReduceMotionEnabled)
                    .onAppear {
                        isAnimating = true
                    }
                    .accessibilityHidden(true) // Icon is decorative
                
                VStack(spacing: 8) {
                    Text("No Workouts Yet")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    
                    Text("Create your first workout to start tracking your fitness journey.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                NavigationLink(destination: AddWorkoutView()) {
                    Label("Create New Workout", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(themeColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("No workouts available. Tap to create your first workout.")
        .accessibilityHint("Double-tap the button below to add a new workout.")
    }
}
