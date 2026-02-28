//
//  PremiumTeaserView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Premium teaser shown when user tries to access gated features.
//  - Clearly explains benefits and links to subscription flow.
//  - Uses StoreKit 2 via PurchaseManager for purchase and restore.
//  - Full VoiceOver accessibility, dynamic type, and high contrast support.
//  - No data collected; all transactions handled securely by Apple.
//

import SwiftUI
import StoreKit

/// Premium teaser screen shown when a user attempts to access a premium-only feature.
/// Educates on benefits and provides a direct path to subscribe.
struct PremiumTeaserView: View {

    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(ErrorManager.self) private var errorManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"

    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }

    @State private var crownAnimating = false
    @State private var selectedProduct: Product?

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.proBackground, .blue.opacity(0.55)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection

                    if purchaseManager.isSubscribed {
                        unlockedStateView
                    } else {
                        featureGridSection
                        pricingSection
                        trustRow
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, purchaseManager.isSubscribed ? 40 : 120)
            }
        }
        .navigationTitle("Go Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !purchaseManager.isSubscribed {
                stickyBottomCTA
            }
        }
        .task {
            await purchaseManager.refresh()
            if selectedProduct == nil {
                selectedProduct = purchaseManager.products.first(where: { $0.id.contains("yearly") })
                    ?? purchaseManager.products.first
            }
        }
        .onChange(of: purchaseManager.products) { _, newProducts in
            if selectedProduct == nil {
                selectedProduct = newProducts.first(where: { $0.id.contains("yearly") })
                    ?? newProducts.first
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                crownAnimating = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(crownAnimating ? 0.18 : 0.08))
                    .frame(width: crownAnimating ? 100 : 88, height: crownAnimating ? 100 : 88)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: crownAnimating)

                Image(systemName: "crown.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: crownAnimating ? 12 : 4)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: crownAnimating)
            }

            Text("Go Premium")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Supercharge your training")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Unlocked State

    private var unlockedStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("Premium Unlocked!")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Enjoy the independent Watch app, advanced metrics, and more.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 10)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - 2-Column Feature Grid

    private var featureGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHAT YOU GET")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(2)

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

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CHOOSE YOUR PLAN")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(2)

            if purchaseManager.products.isEmpty {
                ProgressView("Loading options...")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(purchaseManager.products) { product in
                    SelectableProductCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        themeColor: themeColor
                    ) {
                        selectedProduct = product
                    }
                }
            }
        }
    }

    // MARK: - Trust Row

    private var trustRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
            Text("Cancel anytime · Secured by Apple")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sticky Bottom CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 10) {
            Button {
                guard let product = selectedProduct else { return }
                Task { await purchaseManager.purchase(product) }
            } label: {
                Group {
                    if purchaseManager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(selectedProduct.map { "Subscribe · \($0.displayPrice)" } ?? "Subscribe")
                            .font(.system(.body, design: .rounded, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(selectedProduct == nil || purchaseManager.isPurchasing)

            Button {
                Task { await purchaseManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - FeatureCell

private struct FeatureCell: View {
    let benefit: PremiumBenefit
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

            Text(benefit.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(benefit.description)
                .font(.system(size: 10, design: .default))
                .foregroundStyle(.white.opacity(0.7))
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
    let product: Product
    let isSelected: Bool
    let themeColor: Color
    let onTap: () -> Void

    private var isYearly: Bool { product.id.contains("yearly") }

    private var perMonthText: String? {
        guard isYearly else { return nil }
        let monthly = (product.price as Decimal) / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = product.priceFormatStyle.currencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: monthly as NSDecimalNumber).map { "\($0) / mo" }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? themeColor : .white.opacity(0.35), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(themeColor)
                            .frame(width: 12, height: 12)
                    }
                }

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
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text(product.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
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
                    .strokeBorder(isSelected ? themeColor : Color.clear, lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(product.displayName), \(product.displayPrice)\(isYearly ? ", Best Value" : "")\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Supporting Types

private struct PremiumBenefit: Identifiable, CaseIterable {
    let id       = UUID()
    let icon:    String
    let title:   String
    let description: String

    static let allCases: [PremiumBenefit] = [
        PremiumBenefit(icon: "applewatch",     title: "Watch App",    description: "Full independent Apple Watch app"),
        PremiumBenefit(icon: "heart.fill",     title: "Heart Rate",   description: "Live monitoring & complications"),
        PremiumBenefit(icon: "chart.bar.fill", title: "Analytics",    description: "Intensity, Progress Pulse, Zones"),
        PremiumBenefit(icon: "icloud.fill",    title: "iCloud Sync",  description: "Seamless sync across devices"),
        PremiumBenefit(icon: "sparkles",       title: "AI Insights",  description: "Priority features & AI insights"),
        PremiumBenefit(icon: "bell.badge.fill",title: "Smart Alerts", description: "Personalized training nudges"),
    ]
}
