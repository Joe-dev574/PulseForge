//
//  WorkoutListScreen.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI
import SwiftData
import OSLog
internal import HealthKit



/// Defines filter types for workouts displayed in the workout list.
/// Conforms to CaseIterable and Identifiable for use in SwiftUI pickers.
enum WorkoutFilterType: String, CaseIterable, Identifiable {
    /// Show all workouts.
    case all = "All"
    /// Show workouts filtered by a selected category.
    case category = "Category"
    /// A unique identifier for the filter type.
    var id: String { self.rawValue }
}
/// A SwiftUI view displaying a filtered list of workouts with statistics and navigation options.
/// Integrates StatsSectionView for fitness progress and CategoryPicker for category filtering.

struct WorkoutListScreen: View {
    //MARK: PROPERTIES
    ///ENVIRONMENT
    /// The SwiftData model context for querying workouts.
    @Environment(\.modelContext) private var context
    /// The authentication manager for accessing the current user.
    @Environment(AuthenticationManager.self) private var authManager
    /// The HealthKit manager for syncing workout data.
    @Environment(HealthKitManager.self) private var healthKitManager
    /// The error manager for centralized error handling.
    @Environment(ErrorManager.self) private var errorManager
    /// The color scheme to detect light or dark mode.
    @Environment(\.colorScheme) private var colorScheme
    ///App Storage
    /// The selected theme color, stored in AppStorage.
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData:
    String = "#0096FF"
    /// Query to fetch all workouts, sorted by creation date (newest first).
    @Query(sort: \Workout.dateCreated, order: .reverse) private var allWorkouts:
    [Workout]
    ///STATE PROPERTIES
    /// The current date for filtering and display.
    @State private var currentDate = Date()
    /// State for presenting the add workout sheet.
    @State private var showAddWorkoutSheet = false
    /// State for presenting the progress board sheet.
    @State private var showProgressBoardSheet = false
    /// The selected filter type (all, scheduled, category).
    @State private var selectedFilter: WorkoutFilterType = .all
    /// The category to filter by, if category filter is selected.
    @State private var categoryToFilterBy: Category?
    /// State for presenting the category picker sheet.
    @State private var showingCategoryPickerSheet = false
    /// State to control the display of the HealthKit authorization prompt.
    @State private var showHealthKitAuthorizationPrompt = false
    /// Flag to prevent multiple HealthKit requests.
    @State private var hasRequestedHealthKit = false
    /// Logger for critical error reporting in production.
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier
        ?? "com.tnt.PulseForge.default.subsystem",
        category: "WorkoutListScreen"
    )
    //MARK: MAIN BODY
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()
            NavigationStack {
                filterPickerView
                //MARK:  WORKOUT LIST
                VStack(alignment: .leading, spacing: 0) {
                    //MARK:  Workout list section
                    WorkoutList(workouts: filteredWorkouts)
                        .accessibilityLabel("List of workouts")
                        .accessibilityHint(
                            "Displays filtered workouts; swipe up or down to navigate"
                        )
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: toolbarContent)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .sheet(isPresented: $showAddWorkoutSheet) {
                AddWorkoutView()
                    .presentationDetents([.large])
                    .environment(authManager)
                    .environment(healthKitManager)
                    .environment(errorManager)
            }
            .sheet(isPresented: $showProgressBoardSheet) {
                ProgressBoardView()
                    .presentationDetents([.large])
                    .environment(authManager)
                    .environment(healthKitManager)
                    .environment(errorManager)
            }
            .sheet(isPresented: $showingCategoryPickerSheet) {
                CategoryPicker(selectedCategory: $categoryToFilterBy)
                    .presentationDetents([.large])
                    .onDisappear {
                        if categoryToFilterBy != nil {
                            selectedFilter = .category
                        } else if selectedFilter == .category
                                    && categoryToFilterBy == nil
                        {
                            selectedFilter = .all
                        }
                    }
                    .environment(errorManager)
            }
            .sheet(isPresented: $showHealthKitAuthorizationPrompt) {
                HealthKitPromptView(
                    onAuthorize: {
                        Task {
                            do {
                                try await healthKitManager.requestAuthorization()
                                logger.info(
                                    "HealthKit authorization requested by user"
                                )
                            } catch {
                                errorManager.present(error)
                                logger.error(
                                    "HealthKit authorization failed: \(error.localizedDescription)"
                                )
                            }
                            showHealthKitAuthorizationPrompt = false
                        }
                    },
                    onDismiss: {
                        showHealthKitAuthorizationPrompt = false
                    }
                )
                .presentationDetents([.medium])
                .accessibilityLabel("HealthKit authorization prompt")
            }
            //MARK: ADD WORKOUT BUTTON
            VStack(alignment: .center) {
                Spacer()
                NavigationLink(destination: AddWorkoutView()) {
                    Label("Create New Workout", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color(hex: selectedThemeColorData) ?? .blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }//MARK:  HEALTHKIT PROMPT
            .onAppear {
                logger.info(
                    "Navigated to WorkoutListScreen at \(Date())"
                )
                // Perform a proactive HealthKit status check or lightweight operation
                Task {
                    // Example: Check authorization status for a relevant type (e.g., workout or heart rate)
                    // Adjust the HKObjectType based on your app's required permissions
                    let status = healthKitManager.healthStore.authorizationStatus(for: HKObjectType.workoutType())

                    // If not determined, trigger prompt directly
                    if status == .notDetermined {
                        showHealthKitAuthorizationPrompt = true
                    } else {
                        // Optionally perform a lightweight fetch if needed for your app's logic
                        // For example: try await healthKitManager.fetchSomeMetric() // If applicable
                    }
                }
            }
        }
    }
//MARK:  FILTER PICKER VIEW
/// A view for selecting the workout filter type.
private var filterPickerView: some View {
    Picker("Workout Filter", selection: $selectedFilter) {
        ForEach(WorkoutFilterType.allCases) { filterType in
            Text(
                filterType == .category
                ? (categoryToFilterBy?.categoryName ?? "Category")
                : filterType.rawValue
            )
            .tag(filterType)
        }
        .padding(4)
    }
    .pickerStyle(.segmented)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding(.horizontal)
    .padding(4)
    .padding(.bottom, 5)
    .accessibilityLabel("Workout filter picker")
    .accessibilityHint(
        "Select to filter workouts by category, all, or other options"
    )
    .onChange(of: selectedFilter) { _, newFilter in
        if newFilter == .category {
            showingCategoryPickerSheet = true
        }
        logger.info(
            "[WorkoutListScreen] Selected filter: \(newFilter.rawValue)"
        )
    }
}
    
//MARK:  TOOLBAR CONTENT
/// Toolbar content for navigation and actions.
@ToolbarContentBuilder
private func toolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
        HStack {
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundStyle(
                        Color(hex: selectedThemeColorData) ?? .blue
                    )
                    .padding(.bottom, 2)
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Double-tap to open settings")
            Button {
                showProgressBoardSheet = true
            } label: {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundStyle(
                        Color(hex: selectedThemeColorData) ?? .blue
                    )
                    .padding(.bottom, 2)
            }
            .padding(.horizontal, 4)
            .accessibilityLabel("Progress Board")
            .accessibilityHint("Double-tap to view progress board")
        }
    }
    ToolbarItem(placement: .topBarTrailing) {  //  .navigationBarTrailing in iOS 16+
        NavigationLink {
            if AuthenticationManager.shared.currentUser != nil {
                ProfileView()
            } else {
                // Fallback view if somehow no user is signed in (should not occur in normal flow)
                Text("Profile Unavailable")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        } label: {
            if let currentUser = AuthenticationManager.shared.currentUser,
               let imageData = currentUser.healthMetrics?.profileImageData,
               let uiImage = UIImage(data: imageData)
            {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 3)
                    .overlay(
                        Circle()
                            .stroke(
                                Color(hex: selectedThemeColorData) ?? .blue,
                                lineWidth: 1
                            )
                    )
            } else {
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundStyle(
                        Color(hex: selectedThemeColorData) ?? .blue
                    )
            }
        }
        .accessibilityLabel("Profile")
        .accessibilityHint("Double-tap to view and edit your profile")
    }
}
//MARK:  FILTER ALL WORKOUTS
/// Filters and sorts all workouts by creation date.
/// - Returns: An array of sorted workouts.
/// The filtered list of workouts based on the selected filter type.
private var filteredWorkouts: [Workout] {
    let workouts: [Workout]
    switch selectedFilter {
    case .all:
        workouts = allWorkouts
    case .category:
        workouts =
        categoryToFilterBy.map { category in
            allWorkouts.filter { $0.category == category }
        } ?? []
    }
    return workouts.sorted { $0.dateCreated > $1.dateCreated }
}
}

