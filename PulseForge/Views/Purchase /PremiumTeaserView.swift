//
//  PremiumTeaserView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Single canonical premium screen for both subscribed and non-subscribed users.
//  - Subscribed users see their active benefits and Apple's native Manage Subscriptions sheet.
//  - Non-subscribed users see benefits, pricing, and a clear purchase CTA.
//  - Uses StoreKit 2 via PurchaseManager for all purchase and restore flows.
//  - Full VoiceOver accessibility, dynamic type, and high contrast support.
//  - No data collected; all transactions handled securely by Apple.
//

import SwiftUI
import StoreKit

/// The single canonical premium view for PulseForge.
///
/// Works in two contexts:
/// - Pushed via `NavigationLink` from `SettingsView` (has a back button)
/// - Presented as a `sheet` from `ProgressBoardView` (shows a Done button)
///
/// Both subscribed and non-subscribed users land here.
/// Subscribed users see their active benefits and can manage their subscription.
/// Non-subscribed users see benefits, pricing, and a clear CTA.
struct PremiumTeaserView: View {

    // MARK: - Environment

    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(ErrorManager.self)    private var errorManager
    @Environment(\.dismiss)            private var dismiss

    // MARK: - App Storage

    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"

    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }

    // MARK: - State

    @State private var crownAnimating          = false
    @State private var selectedProduct: Product? = nil
    @State private var showManageSubscriptions = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Deep navy background — ensures white text is always legible
            // regardless of the user's chosen theme colour.
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.04, green: 0.07, blue: 0.15), location: 0.0),
                    .init(color: Color(red: 0.05, green: 0.11, blue: 0.24), location: 0.5),
                    .init(color: Color(red: 0.04, green: 0.09, blue: 0.20), location: 1.0),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection
                    statusBadge
                    featureGridSection

                    if purchaseManager.isSubscribed {
                        manageSection
                    } else {
                        pricingSection
                        trustRow
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 140)
            }
        }
        .navigationTitle("PulseForge Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .fontWeight(.medium)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomCTA
        }
        .task {
            await purchaseManager.refresh()
            setDefaultProduct()
        }
        .onChange(of: purchaseManager.products) { _, _ in
            setDefaultProduct()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                crownAnimating = true
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        // Force dark rendering so .ultraThinMaterial cards appear as dark
        // frosted glass rather than washed-out white panels.
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            // Animated crown
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(crownAnimating ? 0.2 : 0.08))
                    .frame(
                        width:  crownAnimating ? 104 : 88,
                        height: crownAnimating ? 104 : 88
                    )
                    .animation(
                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: crownAnimating
                    )

                Image(systemName: "crown.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.55), radius: crownAnimating ? 14 : 4)
                    .animation(
                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: crownAnimating
                    )
            }
            .accessibilityHidden(true)

            Text("PulseForge Premium")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .multilineTextAlignment(.center)

            Text(
                purchaseManager.isSubscribed
                    ? "All features unlocked. Thank you for your support."
                    : "Unlock the full PulseForge experience."
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            purchaseManager.isSubscribed
                ? "PulseForge Premium — active subscription"
                : "PulseForge Premium — upgrade to unlock all features"
        )
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        if purchaseManager.isSubscribed {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("PREMIUM ACTIVE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .tracking(1.5)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(
                Capsule().strokeBorder(Color.green.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
            .accessibilityLabel("Premium subscription is active")
        }
    }

    // MARK: - Feature Grid (always visible)

    private var featureGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(
                purchaseManager.isSubscribed ? "YOUR BENEFITS" : "WHAT YOU GET"
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 14
            ) {
                ForEach(PremiumBenefit.allCases) { benefit in
                    FeatureCell(benefit: benefit, themeColor: themeColor)
                }
            }
        }
    }

    // MARK: - Manage Section (subscribed only)

    private var manageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("SUBSCRIPTION")

            Button {
                showManageSubscriptions = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(themeColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(themeColor)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Subscription")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Change plan, cancel, or view billing details")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manage subscription")
            .accessibilityHint("Opens Apple's subscription management screen")

            Button {
                Task { await purchaseManager.restorePurchases() }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Restore Purchases")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Sync your subscription across devices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restore purchases")
            .accessibilityHint("Restores your subscription on this device")
        }
    }

    // MARK: - Pricing Section (non-subscribed only)

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("CHOOSE YOUR PLAN")

            if purchaseManager.products.isEmpty {
                ProgressView("Loading options…")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(purchaseManager.products) { product in
                    SelectableProductCard(
                        product:    product,
                        isSelected: selectedProduct?.id == product.id,
                        themeColor: themeColor
                    ) {
                        selectedProduct = product
                    }
                }
            }
        }
    }

    // MARK: - Trust Row (non-subscribed only)

    private var trustRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.65))
                .accessibilityHidden(true)
            Text("Cancel anytime · Secured by Apple · No hidden fees")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Cancel anytime, secured by Apple, no hidden fees")
    }

    // MARK: - Bottom CTA

    @ViewBuilder
    private var bottomCTA: some View {
        if purchaseManager.isSubscribed {
            // Subscribed: single Manage button
            VStack(spacing: 10) {
                Button {
                    showManageSubscriptions = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Manage Subscription")
                            .font(.system(.body, design: .rounded, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Manage subscription")
                .accessibilityHint("Opens Apple's subscription management screen")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)

        } else {
            // Non-subscribed: subscribe + restore
            VStack(spacing: 10) {
                Button {
                    guard let product = selectedProduct else { return }
                    Task { await purchaseManager.purchase(product) }
                } label: {
                    Group {
                        if purchaseManager.isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text(selectedProduct.map { "Subscribe · \($0.displayPrice)" } ?? "Subscribe")
                                .font(.system(.body, design: .rounded, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .disabled(selectedProduct == nil || purchaseManager.isPurchasing)
                .accessibilityLabel(
                    selectedProduct.map { "Subscribe for \($0.displayPrice)" } ?? "Subscribe"
                )

                Button {
                    Task { await purchaseManager.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .accessibilityLabel("Restore previous purchases")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private func setDefaultProduct() {
        guard selectedProduct == nil, !purchaseManager.products.isEmpty else { return }
        selectedProduct = purchaseManager.products.first { $0.id.contains("yearly") }
            ?? purchaseManager.products.first
    }
}

// MARK: - SectionLabel

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.85))
            .tracking(2)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(text)
    }
}

// MARK: - FeatureCell

private struct FeatureCell: View {
    let benefit:    PremiumBenefit
    let themeColor: Color

    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(themeColor.opacity(0.18))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: benefit.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(themeColor)
                )
                .accessibilityHidden(true)

            Text(benefit.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(benefit.description)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(benefit.title): \(benefit.description)")
    }
}

// MARK: - SelectableProductCard

private struct SelectableProductCard: View {
    let product:    Product
    let isSelected: Bool
    let themeColor: Color
    let onTap:      () -> Void

    private var isYearly: Bool { product.id.contains("yearly") }

    private var perMonthText: String? {
        guard isYearly else { return nil }
        let monthly   = (product.price as Decimal) / 12
        let formatter = NumberFormatter()
        formatter.numberStyle       = .currency
        formatter.currencyCode      = product.priceFormatStyle.currencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: monthly as NSDecimalNumber).map { "\($0) / mo" }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Radio indicator
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? themeColor : .white.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(themeColor)
                            .frame(width: 12, height: 12)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)

                        if isYearly {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.yellow)
                                .clipShape(Capsule())
                        }
                    }

                    if let perMonth = perMonthText {
                        Text(perMonth)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        Text(product.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(.headline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? themeColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(product.displayName), \(product.displayPrice)"
            + (isYearly    ? ", Best Value" : "")
            + (isSelected  ? ", selected"   : "")
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - PremiumBenefit

private struct PremiumBenefit: Identifiable, CaseIterable {
    let id          = UUID()
    let icon:       String
    let title:      String
    let description: String

    static let allCases: [PremiumBenefit] = [
        PremiumBenefit(icon: "applewatch",      title: "Watch App",    description: "Full independent Apple Watch app"),
        PremiumBenefit(icon: "heart.fill",      title: "Heart Rate",   description: "Live monitoring & complications"),
        PremiumBenefit(icon: "chart.bar.fill",  title: "Analytics",    description: "Intensity, Progress Pulse, Zones"),
        PremiumBenefit(icon: "icloud.fill",     title: "iCloud Sync",  description: "Seamless sync across devices"),
        PremiumBenefit(icon: "sparkles",        title: "AI Insights",  description: "Priority features & AI insights"),
        PremiumBenefit(icon: "bell.badge.fill", title: "Smart Alerts", description: "Personalised training nudges"),
    ]
}
