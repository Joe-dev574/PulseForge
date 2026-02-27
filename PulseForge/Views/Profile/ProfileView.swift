//
//  ProfileView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/23/26.
//  Updated: February 25, 2026
//
//  Apple App Store Compliance:
//  - HealthKit data is fetched only with explicit user authorization and used solely for on-device display and editing.
//  - All profile data (including profile picture) is stored locally in SwiftData.
//  - Premium features are gated behind subscription (handled by PurchaseManager).
//  - Full VoiceOver accessibility, Dynamic Type, and Reduce Motion support.
//  - Complies with App Review Guidelines 5.1.1 (HealthKit) and 3.3.2 (Accessibility).
//  - Weight, Resting HR, and Max HR are displayed and edited as whole numbers (rounded to nearest integer).
//

import SwiftUI
import SwiftData
import PhotosUI
internal import HealthKit

/// A view for displaying and editing the user's profile information, including personal details,
/// health metrics from HealthKit, and profile picture.
///
/// Weight, Resting Heart Rate, and Max Heart Rate are rounded to the nearest whole number for clean display and editing.
struct ProfileView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(ErrorManager.self) private var errorManager
    
    // MARK: - App Storage
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .metric
    @AppStorage("appearanceSetting") private var appearanceSetting: AppearanceSetting = .system
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    // MARK: - State (Internal storage uses Double for HealthKit precision)
    
    @State private var weightKg: Double?
    @State private var heightM: Double?
    @State private var age: Int?
    @State private var restingHeartRate: Double?
    @State private var maxHeartRate: Double?
    @State private var biologicalSexString: String?
    @State private var fitnessGoal: String?
    @State private var profileImageData: Data?
    
    // UI state
    @State private var hasChanges: Bool = false
    @State private var showAlert: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showAuthorizationPrompt: Bool = false
    
    // MARK: - Computed Properties
    
    private var user: User? {
        authManager.currentUser
    }
    
    private var healthMetrics: HealthMetrics? {
        user?.healthMetrics
    }
    
    // MARK: - Bindings (Rounded Whole Numbers for UI)
    
    private var weightBinding: Binding<Double?> {
        Binding(
            get: {
                guard let w = weightKg else { return nil }
                let value = unitSystem == .metric ? w : UnitConverter.convertWeightToImperial(w)
                return round(value)  // Round to nearest whole number
            },
            set: { newValue in
                hasChanges = true
                guard let nv = newValue else {
                    weightKg = nil
                    return
                }
                let rounded = round(nv)
                weightKg = unitSystem == .metric ? rounded : UnitConverter.convertWeightToMetric(rounded)
            }
        )
    }
    
    private var restingHRBinding: Binding<Int?> {
        Binding(
            get: { restingHeartRate.map { Int(round($0)) } },
            set: { newValue in
                hasChanges = true
                restingHeartRate = newValue.map { Double($0) }
            }
        )
    }
    
    private var maxHRBinding: Binding<Int?> {
        Binding(
            get: { maxHeartRate.map { Int(round($0)) } },
            set: { newValue in
                hasChanges = true
                maxHeartRate = newValue.map { Double($0) }
            }
        )
    }
    
    private var feetBinding: Binding<Int?> {
        Binding(
            get: { heightM.map { UnitConverter.convertHeightToImperial($0).feet } },
            set: { newValue in
                hasChanges = true
                guard let nv = newValue else { heightM = nil; return }
                let currentInches = heightM.map { UnitConverter.convertHeightToImperial($0).inches } ?? 0
                heightM = UnitConverter.convertHeightToMetric(Double(nv), Double(currentInches))
            }
        )
    }
    
    private var inchesBinding: Binding<Int?> {
        Binding(
            get: { heightM.map { UnitConverter.convertHeightToImperial($0).inches } },
            set: { newValue in
                hasChanges = true
                guard let nv = newValue else { heightM = nil; return }
                let currentFeet = heightM.map { UnitConverter.convertHeightToImperial($0).feet } ?? 0
                heightM = UnitConverter.convertHeightToMetric(Double(currentFeet), Double(nv))
            }
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()
            
            NavigationStack {
                Form {
                    profilePictureSection
                    personalInformationSection
                    healthMetricsSection
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.proBackground, for: .navigationBar)
                .tint(themeColor)
            }
        }
        .preferredColorScheme(appearanceSetting.colorScheme)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontDesign(.serif)
                    .foregroundStyle(themeColor)
                    .accessibilityLabel("Save profile changes")
                    .accessibilityHint("Double-tap to save your updated profile")
                }
            }
        }
        .alert("Profile Updated", isPresented: $showAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your profile has been successfully saved.")
                .accessibilityLabel("Profile successfully updated")
        }
        .overlay {
            if isLoading {
                ProgressView("Fetching Health Data...")
                    .accessibilityLabel("Fetching health data from HealthKit")
            }
        }
        .sheet(isPresented: $showAuthorizationPrompt) {
            HealthKitPromptView(
                onAuthorize: {
                    Task {
                        do {
                            try await healthKitManager.requestAuthorization()
                            await fetchFromHealthKit()
                        } catch {
                            errorMessage = "Authorization failed: \(error.localizedDescription)"
                        }
                        showAuthorizationPrompt = false
                    }
                },
                onDismiss: {
                    showAuthorizationPrompt = false
                    errorMessage = "HealthKit access is required to fetch your health data. You can enable it later in Settings."
                }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            loadInitialData()
            Task { await fetchFromHealthKit() }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let optimizedData = ImageOptimizer.optimize(imageData: data) {
                    profileImageData = optimizedData
                    hasChanges = true
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var profilePictureSection: some View {
        Section(header: Text("Profile Picture")
            .foregroundStyle(themeColor)
            .fontDesign(.serif)) {
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    if let imageData = profileImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(themeColor, lineWidth: 3))
                            .shadow(radius: 4)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(themeColor)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile picture")
                .accessibilityHint("Double-tap to choose a new profile picture")
        }
    }
    
    private var personalInformationSection: some View {
        Section(header: Text("Personal Information")
            .foregroundStyle(themeColor)
            .fontDesign(.serif)) {
                
                Picker("Biological Sex", selection: $biologicalSexString) {
                    Text("Not Set").tag(String?.none)
                    Text("Male").tag(String?.some("Male"))
                    Text("Female").tag(String?.some("Female"))
                }
                .onChange(of: biologicalSexString) { hasChanges = true }
                
                HStack {
                    Text("Age")
                    Spacer()
                    TextField("Age", value: $age, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: age) { hasChanges = true }
                }
                
                Picker("Fitness Goal", selection: $fitnessGoal) {
                    Text("General Fitness").tag(String?.some("General Fitness"))
                    Text("Weight Loss").tag(String?.some("Weight Loss"))
                    Text("Muscle Gain").tag(String?.some("Muscle Gain"))
                    Text("Endurance").tag(String?.some("Endurance"))
                    Text("Other").tag(String?.some("Other"))
                }
                .onChange(of: fitnessGoal) { hasChanges = true }
        }
        .fontDesign(.serif)
    }
    
    private var healthMetricsSection: some View {
        Section(header: Text("Health Metrics")
            .foregroundStyle(themeColor)
            .fontDesign(.serif)) {
                
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField(unitSystem == .metric ? "kg" : "lbs", value: weightBinding, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                if unitSystem == .metric {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("m", value: $heightM, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: heightM) { hasChanges = true }
                    }
                } else {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("ft", value: feetBinding, format: .number)
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 50)
                        Text("in")
                        TextField("", value: inchesBinding, format: .number)
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 50)
                    }
                }
                
                HStack {
                    Text("Resting HR")
                    Spacer()
                    TextField("bpm", value: restingHRBinding, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Max HR")
                    Spacer()
                    TextField("bpm", value: maxHRBinding, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
        }
        .fontDesign(.serif)
    }
    
    // MARK: - Private Methods
    
    /// Loads initial data from SwiftData or creates a new HealthMetrics object if none exists.
    private func loadInitialData() {
        guard let metrics = healthMetrics else {
            let newMetrics = HealthMetrics()
            user?.healthMetrics = newMetrics
            modelContext.insert(newMetrics)
            try? modelContext.save()
            return
        }
        
        weightKg = metrics.weight
        heightM = metrics.height
        age = metrics.age
        restingHeartRate = metrics.restingHeartRate
        maxHeartRate = metrics.maxHeartRate
        biologicalSexString = metrics.biologicalSexString
        fitnessGoal = metrics.fitnessGoal ?? "General Fitness"
        profileImageData = metrics.profileImageData
    }
    
    /// Fetches health data from HealthKit and updates local state.
    private func fetchFromHealthKit() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (fetchedWeight, fetchedHeight, fetchedMaxHR) = try await healthKitManager.fetchHealthMetrics()
            
            let biologicalSex = try healthKitManager.healthStore.biologicalSex().biologicalSex
            let sexString: String? = {
                switch biologicalSex {
                case .male: return "Male"
                case .female: return "Female"
                case .other: return "Other"
                default: return "Not Set"
                }
            }()
            
            let dobComponents = try? healthKitManager.healthStore.dateOfBirthComponents()
            let fetchedAge = dobComponents?.date.map {
                Calendar.current.dateComponents([.year], from: $0, to: Date()).year
            } ?? nil
            
            let restingHR = await healthKitManager.fetchLatestRestingHeartRateAsync()
            
            await MainActor.run {
                if weightKg == nil { weightKg = fetchedWeight }
                if heightM == nil { heightM = fetchedHeight }
                if age == nil { age = fetchedAge }
                if restingHeartRate == nil { restingHeartRate = restingHR }
                if maxHeartRate == nil { maxHeartRate = fetchedMaxHR }
                if biologicalSexString == nil { biologicalSexString = sexString }
                
                hasChanges = true
            }
        } catch {
            await MainActor.run {
                if let hkError = error as? HKError,
                   hkError.code == .errorAuthorizationDenied || hkError.code == .errorAuthorizationNotDetermined {
                    showAuthorizationPrompt = true
                } else {
                    errorMessage = "Failed to fetch health data: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Saves all profile changes to SwiftData (with rounding applied).
    private func saveProfile() {
        guard let metrics = healthMetrics else { return }
        
        metrics.weight = weightKg.map { round($0) }
        metrics.height = heightM
        metrics.age = age
        metrics.restingHeartRate = restingHeartRate.map { round($0) }
        metrics.maxHeartRate = maxHeartRate.map { round($0) }
        metrics.biologicalSexString = biologicalSexString
        metrics.fitnessGoal = fitnessGoal
        metrics.profileImageData = profileImageData
        
        do {
            try modelContext.save()
            hasChanges = false
            showAlert = true
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
        }
    }
}
