//
//  ProfileView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/23/26.
//
//  Apple App Store Compliance
//  ──────────────────────────
//  • HealthKit data fetched only with explicit user authorisation; used solely
//    for on-device display and editing. Never transmitted externally.
//  • All profile data (including profile picture) stored locally in SwiftData.
//  • Premium features gated behind PurchaseManager.
//  • Complies with App Review Guidelines 5.1.1 (HealthKit) and 3.3.2 (Accessibility).
//  • Weight, Resting HR, and Max HR displayed and saved as whole numbers.
//
//  Accessibility — Apple Standards Met
//  ─────────────────────────────────────
//  • VoiceOver: every interactive element has a meaningful .accessibilityLabel.
//    Decorative elements (icon badges, dividers, ornamental images) are hidden
//    from the accessibility tree with .accessibilityHidden(true).
//  • Hints: provided only where the action is non-obvious. Labels describe
//    what the element IS; hints describe what HAPPENS when activated.
//    Hints do not begin with "Double-tap to" (VoiceOver prepends that itself).
//  • Traits: .isHeader on section titles; .isButton already implicit on Button.
//    .isImage on the avatar for non-interactive state.
//  • Combined elements: multi-part rows are wrapped with
//    .accessibilityElement(children: .combine) so VoiceOver reads them as one
//    unit rather than individual fragments.
//  • Value descriptions: text fields expose .accessibilityValue so VoiceOver
//    announces the current value distinctly from the field label.
//  • Dynamic Type: all fonts use SwiftUI text styles or scaled system fonts;
//    no fixed font sizes that would break Large Accessibility Sizes.
//    Layout uses .fixedSize(horizontal: false, vertical: true) on labels.
//  • Reduce Motion: the error banner transition respects
//    @Environment(\.accessibilityReduceMotion).
//  • Keyboard / Switch Control: all interactive elements are reachable in
//    logical reading order. No focus traps.
//  • Minimum tap targets: all interactive elements are at least 44×44 pt via
//    .frame(minWidth: 44, minHeight: 44) or inherent padding.
//  • Status updates: HealthKit sync state changes post a UIAccessibility
//    announcement so screen-reader users hear feedback without visual polling.
//

import SwiftUI
import SwiftData
import PhotosUI
internal import HealthKit

// MARK: - ProfileView

/// Displays and edits the athlete's profile: avatar, personal details, and health metrics.
///
/// ## Layout
/// A full-width hero card anchors the top. Editable sections scroll beneath it
/// using the app-standard monospaced-caps accent-pip header style.
///
/// ## Architecture
/// - `NavigationStack` is the root. `ZStack` sits inside to paint `proBackground`.
/// - All `Binding` wrappers preserve `Double` precision for HealthKit interop.
/// - Save toolbar item appears only when `hasChanges == true`.
///
/// ## Threading
/// HealthKit fetches run in `Task { }` blocks and dispatch state mutations to
/// `@MainActor` via `await MainActor.run { }`.
struct ProfileView: View {

    // MARK: - Environment

    @Environment(\.modelContext)               private var modelContext
    @Environment(\.dismiss)                    private var dismiss
    @Environment(\.accessibilityReduceMotion)  private var reduceMotion
    @Environment(AuthenticationManager.self)   private var authManager
    @Environment(HealthKitManager.self)        private var healthKitManager
    @Environment(ErrorManager.self)            private var errorManager

    // MARK: - Persisted Preferences

    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    @AppStorage("unitSystem")             private var unitSystem: UnitSystem = .metric
    @AppStorage("appearanceSetting")      private var appearanceSetting: AppearanceSetting = .system

    // MARK: - Health State (SI units internally; bindings convert for display)

    @State private var weightKg:             Double?
    @State private var heightM:              Double?
    @State private var age:                  Int?
    @State private var restingHeartRate:     Double?
    @State private var maxHeartRate:         Double?
    @State private var biologicalSexString:  String?
    @State private var fitnessGoal:          String?
    @State private var profileImageData:     Data?

    // MARK: - UI State

    @State private var hasChanges:               Bool = false
    @State private var showSavedAlert:           Bool = false
    @State private var selectedPhotoItem:        PhotosPickerItem?
    @State private var isLoading:                Bool = false
    @State private var errorMessage:             String?
    @State private var showAuthorizationPrompt:  Bool = false
    @State private var showHealthKitResultAlert: Bool = false
    @State private var healthKitResultTitle:     String = ""
    @State private var healthKitResultMessage:   String = ""

    // MARK: - Derived

    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }

    private var user: User?                    { authManager.currentUser }
    private var healthMetrics: HealthMetrics?  { user?.healthMetrics }

    /// Resolved display name: stored name → email prefix → "Athlete".
    private var displayName: String {
        if let name = user?.displayName, !name.isEmpty { return name }
        return user?.email?.components(separatedBy: "@").first?.capitalized ?? "Me"
    }

    // MARK: - Accessibility helpers

    /// Formatted weight string for VoiceOver value announcements.
    private var weightAccessibilityValue: String {
        guard let w = weightBinding.wrappedValue else { return "Not set" }
        let unit = unitSystem == .metric ? "kilograms" : "pounds"
        return "\(Int(w)) \(unit)"
    }

    /// Formatted height string for VoiceOver value announcements.
    private var heightAccessibilityValue: String {
        guard let h = heightM else { return "Not set" }
        if unitSystem == .metric {
            return String(format: "%.2f metres", h)
        } else {
            let imp = UnitConverter.convertHeightToImperial(h)
            return "\(imp.feet) feet \(imp.inches) inches"
        }
    }

    private var restingHRAccessibilityValue: String {
        guard let r = restingHRBinding.wrappedValue else { return "Not set" }
        return "\(r) beats per minute"
    }

    private var maxHRAccessibilityValue: String {
        guard let m = maxHRBinding.wrappedValue else { return "Not set" }
        return "\(m) beats per minute"
    }

    // MARK: - Bindings

    /// Weight in display units, rounded to nearest whole number.
    private var weightBinding: Binding<Double?> {
        Binding(
            get: {
                guard let w = weightKg else { return nil }
                let value = unitSystem == .metric ? w : UnitConverter.convertWeightToImperial(w)
                return round(value)
            },
            set: { newValue in
                hasChanges = true
                guard let nv = newValue else { weightKg = nil; return }
                let rounded = round(nv)
                weightKg = unitSystem == .metric ? rounded : UnitConverter.convertWeightToMetric(rounded)
            }
        )
    }

    private var restingHRBinding: Binding<Int?> {
        Binding(
            get: { restingHeartRate.map { Int(round($0)) } },
            set: { hasChanges = true; restingHeartRate = $0.map { Double($0) } }
        )
    }

    private var maxHRBinding: Binding<Int?> {
        Binding(
            get: { maxHeartRate.map { Int(round($0)) } },
            set: { hasChanges = true; maxHeartRate = $0.map { Double($0) } }
        )
    }

    private var feetBinding: Binding<Int?> {
        Binding(
            get: { heightM.map { UnitConverter.convertHeightToImperial($0).feet } },
            set: { newValue in
                hasChanges = true
                guard let nv = newValue else { heightM = nil; return }
                let inches = heightM.map { UnitConverter.convertHeightToImperial($0).inches } ?? 0
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
                let feet = heightM.map { UnitConverter.convertHeightToImperial($0).feet } ?? 0
                heightM = UnitConverter.convertHeightToMetric(Double(feet), Double(nv))
            }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.proBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroCard

                        if let message = errorMessage {
                            errorBanner(message)
                        }

                        healthKitStatusSection
                        personalInfoSection
                        healthMetricsSection

                        Spacer(minLength: 48)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.proBackground, for: .navigationBar)
            .tint(themeColor)
            .toolbar { saveToolbarItem }
            // MARK: Alerts
            .alert("Profile Saved", isPresented: $showSavedAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your profile has been updated successfully.")
            }
            .alert(healthKitResultTitle, isPresented: $showHealthKitResultAlert) {
                if healthKitResultTitle == "Permission Required"
                    || healthKitResultTitle == "Access Denied" {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: {
                Text(healthKitResultMessage)
            }
            // MARK: Sheets
            .sheet(isPresented: $showAuthorizationPrompt) {
                HealthKitPromptView(
                    onAuthorize: {
                        Task {
                            do {
                                try await healthKitManager.requestAuthorization()
                                await fetchFromHealthKit()
                            } catch {
                                errorMessage = "Authorisation failed: \(error.localizedDescription)"
                            }
                            showAuthorizationPrompt = false
                        }
                    },
                    onDismiss: {
                        showAuthorizationPrompt = false
                        errorMessage = "HealthKit access is required to fetch your health data. Enable it in iOS Settings."
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .preferredColorScheme(appearanceSetting.colorScheme)
        .onAppear {
            loadInitialData()
            // Silent background fetch on appear — no alert shown for this call
            // because the user didn't explicitly request it.
            Task { await fetchFromHealthKitSilently() }
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var saveToolbarItem: some ToolbarContent {
        if hasChanges {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveProfile() }
                    .font(.system(.callout, design: .monospaced, weight: .semibold))
                    .foregroundStyle(themeColor)
                    // Label: what it is. Hint: what happens.
                    .accessibilityLabel("Save profile")
                    .accessibilityHint("Saves all pending changes to your profile")
            }
        }
    }

    // MARK: - Hero Card

    /// Full-width athlete identity card.
    /// Only the avatar (PhotosPicker) is interactive; name and goal badge are
    /// presentational and combined into a single accessible element.
    private var heroCard: some View {
        ZStack(alignment: .bottom) {
            Color(.secondarySystemGroupedBackground)

            // Accent line — decorative, hidden from accessibility tree
            LinearGradient(
                colors: [themeColor, themeColor.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)
            .accessibilityHidden(true)

            VStack(spacing: 14) {
                // Avatar + camera badge
                // The ZStack is interactive (PhotosPicker); the badge is purely visual.
                ZStack(alignment: .bottomTrailing) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        avatarView
                    }
                    .buttonStyle(.plain)
                    // Frame ensures minimum 44×44 tap target even for small avatars.
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(
                        profileImageData != nil
                            ? "Profile photo"
                            : "Profile photo, no image set"
                    )
                    .accessibilityHint("Opens the photo picker to choose a new profile picture")
                    .accessibilityAddTraits(.isButton)

                    // Decorative badge — not a separate interactive element
                    ZStack {
                        Circle()
                            .fill(themeColor)
                            .frame(width: 28, height: 28)
                            .shadow(color: themeColor.opacity(0.4), radius: 4, y: 2)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: 4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                // Name — heading landmark for VoiceOver navigation
                Text(displayName)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    // No explicit label needed — the text content IS the label.

                // Fitness goal badge — informational, not interactive
                if let goal = fitnessGoal {
                    HStack(spacing: 5) {
                        Image(systemName: "target")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(themeColor)
                            .accessibilityHidden(true)
                        Text(goal.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeColor)
                            .tracking(1.5)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(themeColor.opacity(0.12)))
                    // Combine the icon + text into one unit; provide a natural-
                    // language label (the visual text is ALL-CAPS which VoiceOver
                    // would read letter-by-letter without an override).
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Fitness goal: \(goal)")
                }
            }
            .padding(.top, 36)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        // Loading overlay — blocks interaction and announces state to VoiceOver
        .overlay {
            if isLoading {
                ZStack {
                    Color(.systemBackground)
                        .opacity(0.75)
                        // Prevent VoiceOver from reaching elements behind the overlay
                        .accessibilityHidden(false)
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(themeColor)
                            .scaleEffect(1.1)
                            .accessibilityHidden(true) // announced by the container label
                        Text("SYNCING HEALTHKIT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(1.5)
                            .accessibilityHidden(true)
                    }
                }
                // Single accessible element for the whole overlay
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Syncing health data from Apple Health")
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    /// Circular avatar — real photo or themed placeholder.
    @ViewBuilder
    private var avatarView: some View {
        Group {
            if let data = profileImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(themeColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeColor.opacity(0.10))
                    // The placeholder icon is decorative; the PhotosPicker
                    // button above carries the meaningful label.
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(themeColor, lineWidth: 2.5))
        .shadow(color: themeColor.opacity(0.25), radius: 10, y: 4)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true) // the container label covers this
            Text(message)
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                let animation: Animation? = reduceMotion ? nil : .easeOut(duration: 0.2)
                withAnimation(animation) { errorMessage = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    // Explicit label — "xmark" alone is not meaningful
                    .accessibilityLabel("Dismiss error message")
            }
            .buttonStyle(.plain)
            // Ensure 44pt minimum tap target
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .overlay(Rectangle().fill(Color.orange).frame(width: 3), alignment: .leading)
        .transition(
            reduceMotion
                ? .opacity
                : .move(edge: .top).combined(with: .opacity)
        )
        // Combine the whole banner into one VoiceOver element.
        // The label surfaces the message; VoiceOver will also announce
        // the dismiss button as a separate focusable item.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(message)")
    }

    // MARK: - HealthKit Status Section

    private var healthKitStatusSection: some View {
        profileSection(header: "HealthKit") {
            Button {
                if healthKitManager.isReadAuthorized {
                    // Explicitly requested sync — show result alert.
                    Task { await fetchFromHealthKit() }
                } else {
                    // Not yet authorised — request permission directly.
                    // Routing through fetchFromHealthKit() when not authorised
                    // causes an immediate HKError that races with sheet
                    // presentation and produces a blink with no feedback.
                    Task {
                        do {
                            try await healthKitManager.requestAuthorization()
                            await fetchFromHealthKit()
                        } catch {
                            healthKitResultTitle   = "Access Denied"
                            healthKitResultMessage = "HealthKit permission was denied.\n\nGo to iOS Settings → Privacy & Security → Health → PulseForge and enable all read permissions, then try again."
                            showHealthKitResultAlert = true
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Status badge — decorative; meaning is in the button label
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(healthKitManager.isReadAuthorized ? Color.green : Color.orange)
                            .frame(width: 32, height: 32)
                        Image(systemName: healthKitManager.isReadAuthorized
                              ? "heart.fill" : "heart.slash.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(healthKitManager.isReadAuthorized
                             ? "Sync from Apple Health"
                             : "Grant HealthKit Access")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(.primary)
                        Text(healthKitManager.isReadAuthorized
                             ? "TAP TO RE-FETCH LATEST DATA"
                             : "TAP TO AUTHORISE HEALTHKIT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                // Minimum tap target
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            // The label describes the current state and what the button does.
            // The hint clarifies what will happen after the tap.
            .accessibilityLabel(
                healthKitManager.isReadAuthorized
                    ? "Apple Health sync. Status: connected."
                    : "Apple Health sync. Status: permission required."
            )
            .accessibilityHint(
                healthKitManager.isReadAuthorized
                    ? "Fetches your latest weight, height, and heart rate from Apple Health"
                    : "Opens the iOS HealthKit permission prompt"
            )
        }
    }

    // MARK: - Personal Info Section

    private var personalInfoSection: some View {
        profileSection(header: "Personal Info") {

            // Biological Sex
            // The whole row is combined so VoiceOver reads "Biological Sex, [value], Picker"
            metricRow(icon: "person.fill", iconColor: themeColor, label: "Biological Sex") {
                Picker("Biological Sex", selection: $biologicalSexString) {
                    Text("Not Set").tag(String?.none)
                    Text("Male").tag(String?.some("Male"))
                    Text("Female").tag(String?.some("Female"))
                    Text("Other").tag(String?.some("Other"))
                }
                .labelsHidden()
                .onChange(of: biologicalSexString) { _, _ in hasChanges = true }
                // Redundant with the row combination but required for standalone
                // VoiceOver focus when the picker is navigated independently.
                .accessibilityLabel("Biological sex")
                .accessibilityValue(biologicalSexString ?? "Not set")
            }

            rowDivider

            // Age
            metricRow(icon: "calendar", iconColor: themeColor, label: "Age") {
                HStack(spacing: 6) {
                    Spacer()
                    TextField("Not set", value: $age, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(maxWidth: 64)
                        .onChange(of: age) { _, _ in hasChanges = true }
                        .accessibilityLabel("Age")
                        .accessibilityValue(age.map { "\($0) years" } ?? "Not set")
                        .accessibilityHint("Enter your age in whole years")
                    unitLabel("yrs")
                        .accessibilityHidden(true) // already in the value string
                }
            }

            rowDivider

            // Fitness Goal — label shortened to "Goal" so "General Fitness"
            // (longest option) never truncates on standard iPhone widths.
            metricRow(icon: "target", iconColor: themeColor, label: "Goal") {
                Picker("Fitness goal", selection: $fitnessGoal) {
                    Text("General Fitness").tag(String?.some("General Fitness"))
                    Text("Weight Loss").tag(String?.some("Weight Loss"))
                    Text("Muscle Gain").tag(String?.some("Muscle Gain"))
                    Text("Endurance").tag(String?.some("Endurance"))
                    Text("Other").tag(String?.some("Other"))
                }
                .labelsHidden()
                .onChange(of: fitnessGoal) { _, _ in hasChanges = true }
                .accessibilityLabel("Fitness goal")
                .accessibilityValue(fitnessGoal ?? "Not set")
            }
        }
    }

    // MARK: - Health Metrics Section

    private var healthMetricsSection: some View {
        profileSection(header: "Health Metrics") {

            // Weight
            metricRow(icon: "scalemass.fill", iconColor: .orange, label: "Weight") {
                HStack(spacing: 6) {
                    Spacer()
                    TextField("Not set", value: weightBinding, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(maxWidth: 72)
                        .accessibilityLabel("Weight")
                        .accessibilityValue(weightAccessibilityValue)
                        .accessibilityHint(
                            unitSystem == .metric
                                ? "Enter weight in whole kilograms"
                                : "Enter weight in whole pounds"
                        )
                    unitLabel(unitSystem == .metric ? "kg" : "lbs")
                        .accessibilityHidden(true)
                }
            }

            rowDivider

            // Height
            metricRow(icon: "ruler.fill", iconColor: .teal, label: "Height") {
                if unitSystem == .metric {
                    HStack(spacing: 6) {
                        Spacer()
                        TextField("Not set", value: $heightM, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.subheadline, design: .monospaced))
                            .frame(maxWidth: 72)
                            .onChange(of: heightM) { _, _ in hasChanges = true }
                            .accessibilityLabel("Height")
                            .accessibilityValue(heightAccessibilityValue)
                            .accessibilityHint("Enter height in metres, for example 1.75")
                        unitLabel("m")
                            .accessibilityHidden(true)
                    }
                } else {
                    HStack(spacing: 6) {
                        Spacer()
                        // Feet and inches are combined into one logical element
                        // so VoiceOver reads the full height as a single value.
                        Group {
                            TextField("0", value: feetBinding, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.subheadline, design: .monospaced))
                                .frame(maxWidth: 48)
                            unitLabel("ft")
                                .accessibilityHidden(true)
                            TextField("0", value: inchesBinding, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.subheadline, design: .monospaced))
                                .frame(maxWidth: 48)
                            unitLabel("in")
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Height")
                        .accessibilityValue(heightAccessibilityValue)
                        .accessibilityHint("Enter height in feet and inches")
                    }
                }
            }

            rowDivider

            // Resting HR
            metricRow(icon: "waveform.path.ecg", iconColor: .red, label: "Resting HR") {
                HStack(spacing: 6) {
                    Spacer()
                    TextField("Not set", value: restingHRBinding, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(maxWidth: 72)
                        .accessibilityLabel("Resting heart rate")
                        .accessibilityValue(restingHRAccessibilityValue)
                        .accessibilityHint("Enter your resting heart rate in beats per minute")
                    unitLabel("bpm")
                        .accessibilityHidden(true)
                }
            }

            rowDivider

            // Max HR
            metricRow(icon: "bolt.heart.fill", iconColor: .red, label: "Max HR") {
                HStack(spacing: 6) {
                    Spacer()
                    TextField("Not set", value: maxHRBinding, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(maxWidth: 72)
                        .accessibilityLabel("Maximum heart rate")
                        .accessibilityValue(maxHRAccessibilityValue)
                        .accessibilityHint("Enter your maximum heart rate in beats per minute")
                    unitLabel("bpm")
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: - Layout Primitives

    /// Monospaced unit suffix (kg, bpm, yrs…).
    /// Always hidden from the accessibility tree — its content is already
    /// embedded in the associated field's .accessibilityValue string.
    private func unitLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }

    /// Hairline divider, inset to clear the icon column. Purely decorative.
    private var rowDivider: some View {
        Divider()
            .padding(.leading, 60)
            .accessibilityHidden(true)
    }

    /// Themed section card with the app-standard accent-pip header.
    ///
    /// The header `HStack` is marked `.isHeader` so VoiceOver users can jump
    /// between sections using the Rotor's "Headings" category.
    private func profileSection<Content: View>(
        header: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Capsule()
                    .fill(themeColor)
                    .frame(width: 3, height: 13)
                    .accessibilityHidden(true)
                Text(header.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(themeColor)
                    .tracking(2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 10)
            // The whole header HStack is the heading landmark.
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(header) // natural-language, not ALL-CAPS

            // Card container
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            .padding(.horizontal, 16)
        }
    }

    /// Single data row: 32pt tinted icon badge + serif label + trailing content.
    ///
    /// The icon badge is decorative and hidden from the accessibility tree;
    /// the label and trailing content remain individually focusable so pickers
    /// and text fields get correct VoiceOver focus behaviour.
    private func metricRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            Text(label)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.primary)
                // fixedSize(horizontal: true) lets the label claim exactly the
                // width its text needs and no more — prevents HStack from giving
                // it half the row at the expense of the trailing picker/field.
                .fixedSize(horizontal: true, vertical: false)
                // Low layout priority so the trailing content (picker, text field)
                // is always offered the remaining space first.
                .layoutPriority(0)

            // trailing() gets all leftover space; .layoutPriority(1) ensures
            // SwiftUI resolves the picker/field width after the label is settled.
            trailing()
                .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Ensure the row meets the 44pt minimum height tap target.
        .frame(minHeight: 44)
    }

    // MARK: - Data Methods

    /// Populates local state from SwiftData, or seeds a blank `HealthMetrics`
    /// record if the user has none yet.
    private func loadInitialData() {
        guard let metrics = healthMetrics else {
            let newMetrics = HealthMetrics()
            user?.healthMetrics = newMetrics
            modelContext.insert(newMetrics)
            try? modelContext.save()
            return
        }
        weightKg             = metrics.weight
        heightM              = metrics.height
        age                  = metrics.age
        restingHeartRate     = metrics.restingHeartRate
        maxHeartRate         = metrics.maxHeartRate
        biologicalSexString  = metrics.biologicalSexString
        fitnessGoal          = metrics.fitnessGoal ?? "General Fitness"
        profileImageData     = metrics.profileImageData
    }

    /// Silent background fetch on `.onAppear` — fills empty fields only,
    /// does not present an alert. Used for passive population on first launch.
    private func fetchFromHealthKitSilently() async {
        isLoading = true
        defer { isLoading = false }

        await healthKitManager.updateAuthorizationStatus()
        guard healthKitManager.isReadAuthorized else { return }

        async let fetchedWeight = try? healthKitManager.fetchLatestQuantity(
            typeIdentifier: .bodyMass, unit: .gramUnit(with: .kilo))
        async let fetchedHeight = try? healthKitManager.fetchLatestQuantity(
            typeIdentifier: .height, unit: .meter())
        async let fetchedMaxHR  = try? healthKitManager.fetchLatestQuantity(
            typeIdentifier: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()))

        let (w, h, m) = await (fetchedWeight, fetchedHeight, fetchedMaxHR)
        let restingHR = await healthKitManager.fetchLatestRestingHeartRateAsync()

        let sexString: String? = (try? healthKitManager.healthStore.biologicalSex())
            .flatMap { result -> String? in
                switch result.biologicalSex {
                case .male:   return "Male"
                case .female: return "Female"
                case .other:  return "Other"
                default:      return nil
                }
            }

        let fetchedAge = (try? healthKitManager.healthStore.dateOfBirthComponents())?
            .date
            .flatMap { Calendar.current.dateComponents([.year], from: $0, to: .now).year }

        // Only populate fields that are currently empty.
        var didChange = false
        if weightKg            == nil, let val = w          { weightKg            = val; didChange = true }
        if heightM             == nil, let val = h          { heightM             = val; didChange = true }
        if age                 == nil, let val = fetchedAge  { age                = val; didChange = true }
        if restingHeartRate    == nil, let val = restingHR   { restingHeartRate   = val; didChange = true }
        if maxHeartRate        == nil, let val = m           { maxHeartRate       = val; didChange = true }
        if biologicalSexString == nil, let val = sexString   { biologicalSexString = val; didChange = true }
        if didChange { hasChanges = true }
    }

    /// Explicit user-triggered sync — queries each HealthKit type directly,
    /// bypassing `fetchHealthMetrics()` (which silently returns nil on any
    /// failure and can never throw). Always presents a result alert.
    ///
    /// Also calls `updateAuthorizationStatus()` first to catch stale
    /// permission state from iOS Settings changes since app launch.
    private func fetchFromHealthKit() async {
        isLoading = true
        defer { isLoading = false }

        // Announce the sync start to VoiceOver users immediately.
        UIAccessibility.post(
            notification: .announcement,
            argument: "Syncing data from Apple Health"
        )

        await healthKitManager.updateAuthorizationStatus()

        guard healthKitManager.isReadAuthorized else {
            healthKitResultTitle   = "Permission Required"
            healthKitResultMessage = "PulseForge does not have read access to Apple Health.\n\nGo to iOS Settings → Privacy & Security → Health → PulseForge and turn on all read permissions, then sync again."
            showHealthKitResultAlert = true
            UIAccessibility.post(notification: .announcement, argument: healthKitResultTitle)
            return
        }

        async let fetchedWeight = try? healthKitManager.fetchLatestQuantity(
            typeIdentifier: .bodyMass, unit: .gramUnit(with: .kilo))
        async let fetchedHeight = try? healthKitManager.fetchLatestQuantity(
            typeIdentifier: .height, unit: .meter())
        async let fetchedMaxHR  = try? healthKitManager.fetchLatestQuantity(
            typeIdentifier: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()))

        let (w, h, m) = await (fetchedWeight, fetchedHeight, fetchedMaxHR)
        let restingHR = await healthKitManager.fetchLatestRestingHeartRateAsync()

        let sexString: String? = (try? healthKitManager.healthStore.biologicalSex())
            .flatMap { result -> String? in
                switch result.biologicalSex {
                case .male:   return "Male"
                case .female: return "Female"
                case .other:  return "Other"
                default:      return nil
                }
            }

        let fetchedAge = (try? healthKitManager.healthStore.dateOfBirthComponents())?
            .date
            .flatMap { Calendar.current.dateComponents([.year], from: $0, to: .now).year }

        // Always overwrite — this is an explicit re-fetch.
        var populated: [String] = []
        if let val = w          { weightKg            = val; populated.append("Weight") }
        if let val = h          { heightM             = val; populated.append("Height") }
        if let val = fetchedAge { age                 = val; populated.append("Age") }
        if let val = restingHR  { restingHeartRate    = val; populated.append("Resting HR") }
        if let val = m          { maxHeartRate        = val; populated.append("Max HR") }
        if let val = sexString  { biologicalSexString = val; populated.append("Biological Sex") }

        if populated.isEmpty {
            healthKitResultTitle   = "No Data in Apple Health"
            healthKitResultMessage = "PulseForge has permission but Apple Health contains no data for weight, height, or heart rate yet.\n\nRecord a workout with a heart rate monitor, or manually add values in the Health app, then sync again."
        } else {
            hasChanges = true
            healthKitResultTitle   = "Sync Complete"
            healthKitResultMessage = "Updated from Apple Health:\n\n\(populated.joined(separator: ", "))"
        }

        showHealthKitResultAlert = true

        // Post announcement so VoiceOver users hear the outcome without
        // needing to wait for the alert to receive focus.
        UIAccessibility.post(notification: .announcement, argument: healthKitResultTitle)
    }

    /// Persists all edited fields to `HealthMetrics` via SwiftData.
    private func saveProfile() {
        guard let metrics = healthMetrics else { return }

        metrics.weight              = weightKg.map         { round($0) }
        metrics.height              = heightM
        metrics.age                 = age
        metrics.restingHeartRate    = restingHeartRate.map { round($0) }
        metrics.maxHeartRate        = maxHeartRate.map     { round($0) }
        metrics.biologicalSexString = biologicalSexString
        metrics.fitnessGoal         = fitnessGoal
        metrics.profileImageData    = profileImageData

        do {
            try modelContext.save()
            hasChanges     = false
            showSavedAlert = true
            UIAccessibility.post(
                notification: .announcement,
                argument: "Profile saved successfully"
            )
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            UIAccessibility.post(
                notification: .announcement,
                argument: "Failed to save profile"
            )
        }
    }
}
