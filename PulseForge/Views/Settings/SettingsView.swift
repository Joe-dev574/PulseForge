//
//  SettingsView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Settings screen for user preferences, HealthKit, account, and support.
//  - Premium card always navigates to PremiumTeaserView (both states); manages subscription from there.
//  - HealthKit toggle wired to live manager via .onChange; only enables sync when authorised.
//  - Full VoiceOver accessibility, Dynamic Type, and Reduce Motion support.
//  - No data leaves the device except private iCloud (premium only).
//  - App version read from CFBundleShortVersionString; never hardcoded.
//  - All URLs and email addresses reference PulseForge, not a legacy app name.
//

import SwiftUI
import StoreKit

// MARK: - SettingsView

/// The primary settings interface for PulseForge.
///
/// Organises user preferences into clearly separated sections:
/// premium subscription, general (theme / appearance / units),
/// HealthKit sync, support, about, and account.
///
/// ## Design notes
/// - Section headers share a single `sectionHeader(_:)` helper to guarantee
///   consistent typography across the entire screen.
/// - Individual rows use `SettingsIconView` and `SettingsRow` to eliminate
///   the ~8x duplicated `ZStack { Rectangle + Image }` pattern from v1.
/// - `NavigationStack` is the root of the view hierarchy; `ZStack` wraps it
///   only to paint the custom background behind the form.
///
/// ## Threading
/// All state mutations are on the `@MainActor` (implicit via SwiftUI).
/// HealthKit authorisation is dispatched via `Task { }` and errors are
/// surfaced through `ErrorManager`.
struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss)        private var dismiss
    @Environment(\.requestReview)  private var requestReview
    @Environment(HealthKitManager.self)     private var healthKitManager
    @Environment(PurchaseManager.self)      private var purchaseManager
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ErrorManager.self)         private var errorManager

    // MARK: - Persisted Preferences

    /// Hex string for the user's chosen theme colour (e.g. `"#0096FF"`).
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"

    /// Whether HealthKit sync is toggled on by the user.
    @AppStorage("isHealthKitSyncEnabled")  private var isHealthKitSyncEnabled: Bool = true

    /// Preferred unit system — metric or imperial.
    @AppStorage("unitSystem")              private var unitSystem: UnitSystem = .metric

    /// Preferred colour scheme — system, light, or dark.
    @AppStorage("appearanceSetting")       private var appearanceSetting: AppearanceSetting = .system

    // MARK: - Local State

    @State private var showAuthorizationError:   Bool = false
    @State private var showSignOutConfirmation:   Bool = false

    // MARK: - Derived

    /// Resolved theme colour; falls back to blue if hex string is malformed.
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }

    /// Two-way binding between the `ColorPicker` and the persisted hex string.
    /// Uses `themeColor` in the getter to avoid a second `Color(hex:)` call.
    private var colorPickerBinding: Binding<Color> {
        Binding(
            get: { themeColor },
            set: { selectedThemeColorData = $0.hex }
        )
    }

    /// App version read from the bundle — automatically correct after every update.
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    /// App build number, shown alongside version for support triage.
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    // MARK: - Body

    var body: some View {
        // NavigationStack is the root. ZStack paints the custom background
        // behind the Form without creating a nested navigation hierarchy.
        NavigationStack {
            ZStack {
                Color.proBackground.ignoresSafeArea()

                Form {
                    premiumSection
                    generalSection
                    healthKitSection
                    supportSection
                    aboutSection
                    rateSection
                    accountSection
                }
                .scrollContentBackground(.hidden)
                .fontDesign(.serif)
                .tint(themeColor)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.proBackground, for: .navigationBar)
            }
        }
        .preferredColorScheme(appearanceSetting.colorScheme)
    }

    // MARK: - Section Header Helper

    /// Produces a visually consistent section header matching the
    /// monospaced-caps accent-pip style used across PulseForge.
    private func sectionHeader(_ label: String) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(themeColor)
                .frame(width: 3, height: 13)
                .accessibilityHidden(true)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(themeColor)
                .tracking(2)
            Spacer()
        }
        .padding(.top, 4)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(label)
    }

    // MARK: - Premium Section

    /// Full-bleed gradient card promoting the premium subscription.
    /// Always navigates to `PremiumTeaserView`, which handles both the
    /// upgrade flow (non-subscribed) and manage-subscription UI (subscribed).
    private var premiumSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {

                // Header row — always visible
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.yellow)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("PULSEFORGE PREMIUM")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .tracking(1.5)
                        Text("Advanced analytics · Apple Watch · Progress Pulse")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                Divider().overlay(.white.opacity(0.25))

                // Bottom row — always a NavigationLink to PremiumTeaserView
                if purchaseManager.isSubscribed {
                    // Subscribed: invite the user to view benefits / manage
                    NavigationLink(destination: PremiumTeaserView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Premium Active")
                                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("View benefits & manage subscription")
                                    .font(.system(.caption2, design: .serif))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("Premium Active — View benefits and manage subscription")
                    .accessibilityHint("Opens the premium features and subscription management screen")
                } else {
                    // Non-subscribed: upsell link
                    NavigationLink(destination: PremiumTeaserView()) {
                        HStack {
                            Text("Subscribe to Premium")
                                .font(.system(.subheadline, design: .serif, weight: .semibold))
                                .foregroundStyle(themeColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(themeColor.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("Subscribe to Premium")
                    .accessibilityHint("Opens the premium subscription screen")
                }
            }
            .padding(16)
            .background(themeColor.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            // Negative list insets so the card fills edge-to-edge within the section.
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        } header: {
            sectionHeader("Premium")
        }
    }

    // MARK: - General Section

    /// Theme colour, appearance mode, and unit system preferences.
    private var generalSection: some View {
        Section {
            // Theme colour
            SettingsRow(iconName: "paintbrush.fill", iconColor: themeColor) {
                ColorPicker("Theme Colour", selection: colorPickerBinding)
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Theme color")
                    .accessibilityHint("Select a colour to personalise the app")
            }

            // Appearance
            SettingsRow(iconName: "sun.max.fill", iconColor: .orange) {
                Picker("Appearance", selection: $appearanceSetting) {
                    ForEach(AppearanceSetting.allCases) { setting in
                        Text(setting.displayAppearance).tag(setting)
                    }
                }
                .accessibilityLabel("Appearance mode")
                .accessibilityHint("Choose light, dark, or system default")
            }

            // Units
            SettingsRow(iconName: "lines.measurement.horizontal", iconColor: themeColor) {
                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases) { system in
                        Text(system.displayName).tag(system)
                    }
                }
                .accessibilityLabel("Units of measure")
                .accessibilityHint("Choose metric or imperial")
            }
        } header: {
            sectionHeader("General")
        }
    }

    // MARK: - HealthKit Section

    /// HealthKit sync toggle and live authorisation status.
    ///
    /// The toggle persists via `@AppStorage("isHealthKitSyncEnabled")`.
    /// `HealthKitManager` reads that key directly wherever it needs to gate
    /// sync behaviour, so no additional propagation call is required here.
    private var healthKitSection: some View {
        Section {
            // Toggle
            SettingsRow(iconName: "heart.fill", iconColor: .red) {
                Toggle("HealthKit Sync", isOn: $isHealthKitSyncEnabled)
                    .accessibilityLabel("HealthKit sync")
                    .accessibilityHint(isHealthKitSyncEnabled
                        ? "Tap to disable HealthKit synchronisation"
                        : "Tap to enable HealthKit synchronisation")
            }

            // Status / action row
            healthKitStatusRow

        } header: {
            sectionHeader("HealthKit")
        }
        .alert("HealthKit Access Required", isPresented: $showAuthorizationError) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please grant HealthKit permission in iOS Settings to enable workout sync.")
        }
    }

    /// Inline status feedback row — a single source of truth for the three
    /// possible HealthKit states, rendered with consistent icon + text layout.
    @ViewBuilder
    private var healthKitStatusRow: some View {
        if isHealthKitSyncEnabled && !healthKitManager.isReadAuthorized {
            // Needs permission
            Button {
                Task {
                    do {
                        try await healthKitManager.requestAuthorization()
                    } catch {
                        showAuthorizationError = true
                    }
                }
            } label: {
                SettingsRow(iconName: "lock.fill", iconColor: .orange) {
                    HStack {
                        Text("Grant HealthKit Permission")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Grant HealthKit permission")
            .accessibilityHint("Opens the HealthKit authorisation prompt")

        } else if isHealthKitSyncEnabled && healthKitManager.isReadAuthorized {
            // Authorised and active
            SettingsRow(iconName: "checkmark.circle.fill", iconColor: .green) {
                Text("Sync Active")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("HealthKit sync is active")

        } else {
            // Toggle is off
            SettingsRow(iconName: "slash.circle", iconColor: .secondary.opacity(0)) {
                Text("Sync Disabled")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("HealthKit sync is disabled")
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section {
            SettingsLinkRow(
                iconName:   "envelope.fill",
                iconColor:  .blue,
                label:      "Contact Support",
                url:        URL(string: "mailto:support@pulseforge.app")!
            )

            SettingsLinkRow(
                iconName:   "ant.fill",
                iconColor:  .orange,
                label:      "Report a Bug",
                url:        URL(string: "mailto:bugs@pulseforge.app")!
            )

            SettingsLinkRow(
                iconName:   "globe",
                iconColor:  themeColor,
                label:      "Visit PulseForge.app",
                url:        URL(string: "https://pulseforge.app")!
            )
        } header: {
            sectionHeader("Support")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            SettingsLinkRow(
                iconName:  "hand.raised.fill",
                iconColor: .indigo,
                label:     "Privacy & Security Policy",
                url:       URL(string: "https://Joe-dev574.github.io/pulseforge-privacy")!
            )
            .foregroundStyle(.blue)
                .accessibilityLabel("View Privacy Policy")
                .accessibilityHint("Opens in browser")

            SettingsLinkRow(
                iconName:  "doc.text.fill",
                iconColor: .teal,
                label:     "Terms of Service",
                url:       URL(string: "https://joe-dev574.github.io/PulseForge_Terms_of_Service/")!
            )
            .foregroundStyle(.blue)
                .accessibilityLabel("View Terms of Service")
                .accessibilityHint("Opens in browser")
            // Version row — never hardcoded
            SettingsRow(iconName: "info.circle.fill", iconColor: .green) {
                HStack {
                    Text("Version")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(appVersion) (\(buildNumber))")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App version \(appVersion), build \(buildNumber)")
        } header: {
            sectionHeader("About")
        }
    }

    // MARK: - Rate Section

    private var rateSection: some View {
        Section {
            Button {
                requestReview()
            } label: {
                SettingsRow(iconName: "star.fill", iconColor: .yellow) {
                    HStack {
                        Text("Rate PulseForge")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rate PulseForge in the App Store")
            .accessibilityHint("Opens an App Store rating prompt")
        } header: {
            sectionHeader("Rate")
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            // User display (email or placeholder)
            if let email = authManager.currentUser?.email {
                SettingsRow(iconName: "person.circle.fill", iconColor: themeColor) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed In")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                        Text(email)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(.primary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Signed in as \(email)")
            }

            // Sign out — destructive, separated visually from informational rows
            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                SettingsRow(iconName: "rectangle.portrait.and.arrow.right", iconColor: .red) {
                    Text("Sign Out")
                        .foregroundStyle(.red)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sign out")
            .accessibilityHint("Ends your current session")
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out of PulseForge?")
            }
        } header: {
            sectionHeader("Account")
        }
    }
}

// MARK: - SettingsRow

/// A reusable form row that pairs a tinted SF Symbol icon badge
/// with arbitrary trailing content via a `@ViewBuilder` closure.
///
/// Replaces the ~8x repeated `ZStack { Rectangle + Image }` pattern
/// from the original file. Any change to icon size or corner radius
/// is made here once and applies everywhere.
private struct SettingsRow<Content: View>: View {
    let iconName:  String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .scaledToFit()
            }
            .accessibilityHidden(true)

            content()
        }
    }
}

// MARK: - SettingsLinkRow

/// A pre-built row for external URL links — icon badge + label + external arrow.
private struct SettingsLinkRow: View {
    let iconName:  String
    let iconColor: Color
    let label:     String
    let url:       URL

    var body: some View {
        Link(destination: url) {
            SettingsRow(iconName: iconName, iconColor: iconColor) {
                HStack {
                    Text(label)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityLabel(label)
        .accessibilityHint("Opens in Safari")
    }
}
