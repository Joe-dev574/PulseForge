//
//  PurchaseManager.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import StoreKit
import OSLog
import SwiftUI
import Observation

#if os(watchOS)
import WatchKit
#endif

/// Centralized manager for the FitSync Premium subscription ("FitSync Watch").
/// Handles product loading, purchasing, status checking, restoration, and cross-app (iPhone ↔ Watch) premium syncing.
///
/// Premium status is shared safely via App Group UserDefaults so the independent Watch app
/// can correctly gate the full Watch experience without crashing the iPhone app.
@Observable
@MainActor
public class PurchaseManager {
    // MARK: - Shared Instance
    public static let shared = PurchaseManager()
    
    // MARK: - Configuration
    private let monthlyProductID = "com.tnt.PulseForge.premium.monthly"
        private let yearlyProductID = "com.tnt.PulseForge.premium.yearly"
        private let productIDs = ["com.tnt.PulseForge.premium.monthly", "com.tnt.PulseForge.premium.yearly"]
        private let appGroupID = "group.com.tnt.PulseForge"
    
    // MARK: - Observable State
    var products: [Product] = []
        var isSubscribed: Bool = false
        var subscribedProductID: String? = nil
        var isPurchasing: Bool = false
        var message: String?
    
    // MARK: - Private
    private let logger = Logger(subsystem: "com.tnt.PulseForge", category: "PurchaseManager")
    private var transactionListenerTask: Task<Void, Never>?
    
    private init() {
        Task {
            await refresh()
        }
        listenForTransactions()
    }
    @MainActor
    deinit {
        transactionListenerTask?.cancel()
    }
    
    // MARK: - Public API
    
    /// Refresh product and subscription status — call on app launch and after purchase/restore.
    func refresh() async {
        await loadProduct()
        await refreshSubscriptionStatus()
    }
    
    /// Initiates purchase of the premium subscription.
    func purchase(_ product: Product) async {
            isPurchasing = true
            message = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                    await syncPremiumStatusToAppGroup(true)
                    logger.info("Purchase successful: \(transaction.productID)")
                    message = "Premium unlocked! Enjoy the full Watch experience ✨"
                    
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.success)
                    #endif
                } else {
                    logger.warning("Purchase verification failed")
                    message = "Purchase could not be verified."
                }
            case .userCancelled:
                logger.info("User cancelled purchase")
                message = "Purchase cancelled."
            case .pending:
                logger.info("Purchase pending (e.g., Ask to Buy)")
                message = "Purchase pending approval..."
            @unknown default:
                break
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            message = "Purchase failed. Please try again."
        }
        
        isPurchasing = false
    }
    
    /// Restores previously purchased subscriptions — required by App Store guidelines.
    func restorePurchases() async {
        isPurchasing = true
        message = "Restoring purchases..."
        
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            logger.info("Restore completed")
            message = isSubscribed ? "Premium restored successfully!" : "No previous purchase found."
            
            #if os(watchOS)
            if isSubscribed {
                WKInterfaceDevice.current().play(.success)
            }
            #endif
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            message = "Restore failed. Please try again."
        }
        
        isPurchasing = false
    }
    
    // MARK: - Private Helpers
    
    private func loadProduct() async {
        do {
            products = try await Product.products(for: productIDs).sorted { $0.price < $1.price }
                    } catch {
                        logger.error("Failed to load products: \(error.localizedDescription)")
                    }
                }
    
    private func refreshSubscriptionStatus() async {
        isSubscribed = false
                subscribedProductID = nil
                
                for await result in Transaction.currentEntitlements {
                    guard case .verified(let transaction) = result else {
                        continue
                    }
                    
                    if productIDs.contains(transaction.productID),
                       let expirationDate = transaction.expirationDate,
                       expirationDate > Date(),
                       transaction.revocationDate == nil {
                        isSubscribed = true
                        subscribedProductID = transaction.productID
                        await syncPremiumStatusToAppGroup(true)
                        break
                    }
                }
                
                if !isSubscribed {
                    await syncPremiumStatusToAppGroup(false)
                }
            }
    
    /// Syncs premium status to App Group — only executed on iOS.
    /// The Watch reads this flag to enable full independent features.
    private func syncPremiumStatusToAppGroup(_ premium: Bool) async {
        #if os(iOS)
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            logger.error("Failed to access app group UserDefaults")
            return
        }
        defaults.set(premium, forKey: "isPremium")
        defaults.synchronize()
        logger.info("Premium status synced to app group: \(premium)")
        #endif
    }
    
    /// Background listener for transaction updates (renewals, refunds, etc.)
    private func listenForTransactions() {
            transactionListenerTask?.cancel()
            transactionListenerTask = Task.detached {
                for await update in Transaction.updates {
                    switch update {
                    case .verified(let transaction):
                        await transaction.finish()
                        await self.refreshSubscriptionStatus()
                    default:
                        break
                    }
                }
            }
        }
    }

