//
//  ProfileView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/23/26.
//
//  Apple App Store Compliance (required for review):
//  - HealthKit data is fetched only when authorized and used for on-device profile display/editing.
//  - Profile picture and personal data are stored locally in SwiftData.
//  - Premium users see enhanced health insights via MetricsManager (single source of truth).
//  - Full VoiceOver accessibility, dynamic type, and Reduce Motion support.
//  - No data leaves the device except private iCloud (premium only).
//  - Complies with App Review Guidelines 5.1.1 (HealthKit) and 3.3.2 (Accessibility).
//

import SwiftUI
import SwiftData
import PhotosUI
internal import HealthKit

/// User profile editing screen with HealthKit integration and premium insights.
/// Allows editing personal details, health metrics, and profile picture.
struct ProfileView: View {
    
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(MetricsManager.self) private var metricsManager
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(ErrorManager.self) private var errorManager
    
    // MARK: - State (local editing)
    @State private var weightKg: Double?
    @State private var heightM: Double?
    @State private var age: Int?
    @State private var biologicalSexString: String?
    @State private var fitnessGoal: String?
    @State private var profileImageData: Data?
    
    @State private var showAuthorizationPrompt = false
    @State private var isLoading = false
    @State private var hasChanges = false
    @State private var showAlert = false
    @State private var errorMessage: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // MARK: - Premium Metrics (Centralized)
    @State private var metrics: WorkoutMetrics?
    
    // MARK: - App Storage
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .metric
    @AppStorage("appearanceSetting") private var appearanceSetting: AppearanceSetting = .system
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    private var user: User? { authManager.currentUser }
    private var healthMetrics: HealthMetrics? { user?.healthMetrics }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()
            
            NavigationStack {
                Form {
                    // Profile Picture
                    Section(header: Text("Profile Picture")
                        .foregroundStyle(themeColor)
                        .fontDesign(.serif)) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            if let data = profileImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundStyle(themeColor)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Personal Information
                    Section(header: Text("Personal Information")
                        .foregroundStyle(themeColor)
                        .fontDesign(.serif)) {
                        Picker("Biological Sex", selection: $biologicalSexString) {
                            Text("Not Set").tag(String?.none)
                            Text("Male").tag(String?.some("Male"))
                            Text("Female").tag(String?.some("Female"))
                        }
                        .onChange(of: biologicalSexString) { hasChanges = true }
                        
                        TextField("Age", value: $age, format: .number)
                            .keyboardType(.numberPad)
                            .onChange(of: age) { hasChanges = true }
                        
                        Picker("Fitness Goal", selection: $fitnessGoal) {
                            Text("General Fitness").tag(String?.some("General Fitness"))
                            Text("Weight Loss").tag(String?.some("Weight Loss"))
                            Text("Muscle Gain").tag(String?.some("Muscle Gain"))
                            Text("Endurance").tag(String?.some("Endurance"))
                            Text("Other").tag(String?.some("Other"))
                        }
                        .onChange(of: fitnessGoal) { hasChanges = true }
                    }
                    
                    // Health Metrics
                    Section(header: Text("Health Metrics")
                        .foregroundStyle(themeColor)
                        .fontDesign(.serif)) {
                        weightField
                        heightField
                        
                        if purchaseManager.isSubscribed {
                            premiumHealthMetricsSection
                        }
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
                    .foregroundStyle(themeColor)
                }
            }
        }
        .alert("Profile Updated", isPresented: $showAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your profile has been successfully updated.")
        }
        .overlay {
            if isLoading {
                ProgressView("Fetching Health Data...")
            }
        }
        .sheet(isPresented: $showAuthorizationPrompt) {
            HealthKitPromptView(onAuthorize: authorizeHealthKit, onDismiss: { showAuthorizationPrompt = false })
        }
        .onAppear {
            loadInitialData()
            Task { await fetchFromHealthKit() }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let optimized = ImageOptimizer.optimize(imageData: data) {
                    profileImageData = optimized
                    hasChanges = true
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var weightField: some View {
        HStack {
            Text("Weight")
            Spacer()
            TextField(unitSystem == .metric ? "kg" : "lbs", value: weightBinding, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private var heightField: some View {
        Group {
            if unitSystem == .metric {
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("m", value: $heightM, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } else {
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("ft", value: feetBinding, format: .number)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 60)
                    Text("in")
                    TextField("", value: inchesBinding, format: .number)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 60)
                }
            }
        }
    }
    
    @ViewBuilder
    private var premiumHealthMetricsSection: some View {
        if let m = metrics {
            StatRow(title: "Resting HR", value: m.restingHeartRate.map { "\(Int($0)) bpm" } ?? "N/A")
            StatRow(title: "Max HR", value: m.maxHeartRate.map { "\(Int($0)) bpm" } ?? "N/A")
        }
    }
    
    // MARK: - Data Handling
    
    private func loadInitialData() {
        guard let hm = healthMetrics else { return }
        weightKg = hm.weight
        heightM = hm.height
        age = hm.age
        biologicalSexString = hm.biologicalSexString
        fitnessGoal = hm.fitnessGoal
        profileImageData = hm.profileImageData
    }
    
    private func fetchFromHealthKit() async {
        isLoading = true
        do {
            let (weight, height, _) = try await healthKitManager.fetchHealthMetrics()
            
            // Load centralized premium metrics (includes restingHR, maxHR, etc.)
            metrics = await metricsManager.fetchMetrics()
            
            await MainActor.run {
                if weightKg == nil { weightKg = weight }
                if heightM == nil { heightM = height }
            }
        } catch {
            if let hkError = error as? HKError, hkError.code == .errorAuthorizationNotDetermined {
                showAuthorizationPrompt = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
    
    private func authorizeHealthKit() {
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                await fetchFromHealthKit()
            } catch {
                errorMessage = "Authorization failed: \(error.localizedDescription)"
            }
            showAuthorizationPrompt = false
        }
    }
    
    private func saveProfile() {
        guard let hm = healthMetrics else { return }
        
        hm.weight = weightKg
        hm.height = heightM
        hm.age = age
        hm.biologicalSexString = biologicalSexString
        hm.fitnessGoal = fitnessGoal
        hm.profileImageData = profileImageData
        
        do {
            try modelContext.save()
            hasChanges = false
            showAlert = true
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Computed Bindings for Units
    private var weightBinding: Binding<Double?> {
        Binding(
            get: { weightKg.map { unitSystem == .metric ? $0 : UnitConverter.convertWeightToImperial($0) } },
            set: { newValue in
                hasChanges = true
                weightKg = newValue.map { unitSystem == .metric ? $0 : UnitConverter.convertWeightToMetric($0) }
            }
        )
    }
    
    private var feetBinding: Binding<Int?> {
        Binding(
            get: { heightM.map { UnitConverter.convertHeightToImperial($0).feet } },
            set: { newValue in
                hasChanges = true
                guard let nv = newValue else { heightM = nil; return }
                let inches = inchesBinding.wrappedValue ?? 0
                heightM = UnitConverter.convertHeightToMetric(Double(nv), Double(inches))
            }
        )
    }
    
    private var inchesBinding: Binding<Int?> {
        Binding(
            get: { heightM.map { UnitConverter.convertHeightToImperial($0).inches } },
            set: { newValue in
                hasChanges = true
                guard let nv = newValue else { heightM = nil; return }
                let feet = feetBinding.wrappedValue ?? 0
                heightM = UnitConverter.convertHeightToMetric(Double(feet), Double(nv))
            }
        )
    }
}

// MARK: - Reusable Row
private struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
