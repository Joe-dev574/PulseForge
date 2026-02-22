//
//  SubscriptionView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 1/22/26.
//
//  Apple App Store Compliance (required for review):
//  - Uses StoreKit 2 for transparent pricing, purchase, and restore.
//  - Premium features are clearly gated and explained.
//  - Manage Subscriptions sheet is provided by Apple (.manageSubscriptionsSheet).
//  - Full VoiceOver accessibility, dynamic type, and Reduce Motion support.
//  - No sensitive data stored beyond Apple's secure StoreKit flow.
//

import SwiftUI
import StoreKit

/// Subscription management screen.
/// Shows benefits, pricing, purchase/restore options, and current subscription status.
struct SubscriptionView: View {
    
    @Environment(PurchaseManager.self) private var purchaseManager
    @State private var showManageSubscriptions = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.proBackground, .blue.opacity(0.7)]),
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
                    }
                    
                    pricingSection
                    
                    if purchaseManager.isSubscribed {
                        manageSubscriptionButton
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                refreshButton
            }
        }
        .task {
            await purchaseManager.refresh()
        }
        // Official Apple Manage Subscriptions sheet (iOS 16+)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.yellow)
            
            Text("Go Premium")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            
            Text("Unlock the full fitness experience")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }
    
    private var unlockedStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("You're Subscribed!")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Thank you for supporting independent development.\nEnjoy all premium features.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What you get with Premium")
                .font(.headline)
                .foregroundStyle(.white)
            
            ForEach(PremiumBenefit.allCases) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: benefit.icon)
                        .foregroundStyle(.yellow)
                        .frame(width: 24)
                    Text(benefit.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var pricingSection: some View {
        VStack(spacing: 16) {
            if purchaseManager.products.isEmpty {
                ProgressView("Loading subscription options...")
                    .foregroundStyle(.white)
            } else {
                ForEach(purchaseManager.products) { product in
                    SubscriptionOptionButton(product: product)
                }
            }
            
            Button {
                Task { await purchaseManager.restorePurchases() }
            } label: {
                Text("Restore Previous Purchases")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
    
    private var manageSubscriptionButton: some View {
        Button("Manage Subscription") {
            showManageSubscriptions = true
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }
    
    private var refreshButton: some View {
        Button {
            Task { await purchaseManager.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
    }
}

// MARK: - Supporting Views

private struct SubscriptionOptionButton: View {
    let product: Product
    @Environment(PurchaseManager.self) private var purchaseManager
    
    var body: some View {
        Button {
            Task { await purchaseManager.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
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
        PremiumBenefit(icon: "applewatch", description: "Full Apple Watch companion app with independent operation"),
        PremiumBenefit(icon: "heart", description: "Live heart rate monitoring and complications"),
        PremiumBenefit(icon: "chart.bar.fill", description: "Advanced metrics: Intensity Score, Progress Pulse, Zone analysis"),
        PremiumBenefit(icon: "arrow.triangle.2.circlepath", description: "Seamless iCloud sync across devices"),
        PremiumBenefit(icon: "sparkles", description: "Priority new features and AI-powered insights")
    ]
}
