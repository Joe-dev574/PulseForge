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
/// Educates on benefits and provides direct path to subscribe.
struct PremiumTeaserView: View {
    
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(ErrorManager.self) private var errorManager
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.proBackground, .blue.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    
                    if purchaseManager.isSubscribed {
                        unlockedStateView
                    } else {
                        benefitsSection
                        pricingSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 40)
            }
        }
        .navigationTitle("Go Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            await purchaseManager.refresh()
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.yellow)
            
            Text("Unlock Premium")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            
            Text("Get the full NorthTrax experience on Apple Watch and more")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }
    
    private var unlockedStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            
            Text("Premium Unlocked!")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Enjoy independent Watch app, advanced metrics, and more.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.top, 20)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Premium Features")
                .font(.headline)
                .foregroundStyle(.white)
            
            ForEach(PremiumBenefit.allCases) { benefit in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: benefit.icon)
                        .foregroundStyle(.yellow)
                        .frame(width: 28)
                    Text(benefit.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var pricingSection: some View {
        VStack(spacing: 16) {
            if purchaseManager.products.isEmpty {
                ProgressView("Loading options...")
                    .foregroundStyle(.white)
            } else {
                ForEach(purchaseManager.products) { product in
                    SubscriptionOptionButton(product: product)
                }
            }
            
            Button {
                Task { await purchaseManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Supporting Types

private struct SubscriptionOptionButton: View {
    let product: Product
    @Environment(PurchaseManager.self) private var purchaseManager
    
    var body: some View {
        Button {
            Task { await purchaseManager.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(product.displayName)
                        .font(.headline)
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.title3.bold())
                    .monospacedDigit()
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(purchaseManager.isPurchasing)
    }
}

private struct PremiumBenefit: Identifiable, CaseIterable {
    let id = UUID()
    let icon: String
    let description: String
    
    static let allCases: [PremiumBenefit] = [
        PremiumBenefit(icon: "applewatch", description: "Full independent Apple Watch app"),
        PremiumBenefit(icon: "heart", description: "Live heart rate monitoring & complications"),
        PremiumBenefit(icon: "chart.bar.fill", description: "Advanced metrics: Intensity, Progress Pulse, Zones"),
        PremiumBenefit(icon: "arrow.triangle.2.circlepath", description: "Seamless iCloud sync across devices"),
        PremiumBenefit(icon: "sparkles", description: "Priority new features and AI insights")
    ]
}
