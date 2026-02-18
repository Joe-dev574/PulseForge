//
//  ErrorManager.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI
import OSLog
import Observation

// MARK: - App-Specific Errors
/// Custom error types for the NorthTrax app, conforming to LocalizedError for user-friendly messaging.
///
/// These errors cover common failure scenarios like database issues, iCloud unavailability, HealthKit permissions,
/// and in-app purchases. Each provides a title, reason, and recovery suggestion compliant with Apple's
/// Human Interface Guidelines for clear, actionable error handling in production apps.

enum AppError: LocalizedError {
    case databaseError
    case cloudKitUnavailable
    case healthKitNotAuthorized
    case purchaseFailed
    case unknown(Error?)
    case healthKitUnavailable
    
    /// A localized title for the error, suitable for alert headers.
    var errorDescription: String? {
        switch self {
        case .databaseError:          "Database Error"
        case .cloudKitUnavailable:    "iCloud Unavailable"
        case .healthKitNotAuthorized: "Health Access Required"
        case .purchaseFailed:         "Purchase Failed"
        case .unknown:                "Something Went Wrong"
        case .healthKitUnavailable:   "HealthKit Not Available"
        }
    }
    
    /// A localized explanation of why the error occurred.
    var failureReason: String? {
        switch self {
        case .databaseError:
            "We couldn’t save your workout right now."
        case .cloudKitUnavailable:
            "Your device is offline or iCloud is not available."
        case .healthKitNotAuthorized:
            "FitSync needs Health access to track heart rate, calories, and routes."
        case .purchaseFailed:
            "The purchase could not be completed."
        case .unknown(let error):
            error?.localizedDescription ?? "An unexpected error occurred."
        case .healthKitUnavailable:
            "HealthKit is not supported on this device."
        }
    }
    
    /// A localized suggestion for how the user can recover or proceed.
    var recoverySuggestion: String? {
        switch self {
        case .databaseError, .cloudKitUnavailable:
            "Your data is safe and will sync when possible. Keep training."
        case .healthKitNotAuthorized:
            "Tap below to open Settings and grant access."
        case .purchaseFailed:
            "Try again later or contact support."
        case .unknown:
            "Please try again. Restart the app if needed."
        case .healthKitUnavailable:
            "Some features will be limited without HealthKit."
        }
    }
}

// MARK: - Alert Model
/// A model for presenting alerts in the app, ensuring consistency and accessibility.
///
/// This struct encapsulates alert details and includes VoiceOver support per Apple's accessibility guidelines.
/// Use this to create standardized alerts that can be queued and displayed sequentially.
struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?
    
    /// Accessibility label for VoiceOver, combining title and message.
    var accessibilityLabel: String { "\(title). \(message)" }
    
    /// Accessibility hint for VoiceOver, describing interaction options.
    var accessibilityHint: String {
        secondaryButton != nil ?
            "Double-tap to dismiss or choose action." :
            "Double-tap to dismiss."
    }
}

// MARK: - ErrorManager (2025 @Observable Singleton)
/// A singleton manager for handling and presenting errors as alerts in the NorthTrax app.
///
/// This class queues errors to prevent overlapping alerts and uses logging for debugging.
/// It ensures errors are presented on the main thread for UI safety.
///
/// - Note: For production, integrate with analytics (e.g., Crashlytics) to track error frequency.
/// - Important: Always present errors asynchronously if called from background threads.
@MainActor @Observable
public final class ErrorManager {
    /// Shared singleton instance for global access.
    static let shared = ErrorManager()
    
    // Public state
    /// The currently displayed alert, or nil if none.
    var currentAlert: AppAlert?
    
    // Private state
    /// Queue for pending alerts to prevent UI overload.
    private var alertQueue: [AppAlert] = []
    
    /// Logger for error events and alert lifecycle.
    private let logger = Logger(subsystem: "com.tnt.PulseForge", category: "ErrorManager")
    
    // MARK: - Initialization
    /// Private initializer to enforce singleton pattern.
    private init() {}
    
    // MARK: - Present Methods
    /// Presents a custom alert with the given title, message, and buttons.
    ///
    /// If an alert is already showing, this enqueues the new one for sequential display.
    ///
    /// - Parameters:
    ///   - title: The alert title.
    ///   - message: The alert message.
    ///   - primaryButton: The main action button (defaults to "OK").
    ///   - secondaryButton: An optional secondary button (e.g., "Cancel").
    func present(
        title: String,
        message: String,
        primaryButton: Alert.Button = .default(Text("OK")),
        secondaryButton: Alert.Button? = nil
    ) {
        let alert = AppAlert(
            title: title,
            message: message,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton
        )
        enqueueOrPresent(alert)
    }
    
    /// Presents an alert for any Error type, falling back to LocalizedError if possible.
    ///
    /// - Parameters:
    ///   - error: The error to present.
    ///   - secondaryButton: An optional secondary button.
    func present(_ error: Error, secondaryButton: Alert.Button? = nil) {
        if let localized = error as? LocalizedError {
            present(localized, secondaryButton: secondaryButton)
        } else {
            present(AppError.unknown(error))
        }
    }
    
    /// Presents an alert for an AppError.
    ///
    /// - Parameters:
    ///   - error: The AppError to present.
    ///   - secondaryButton: An optional secondary button.
    func present(_ error: AppError, secondaryButton: Alert.Button? = nil) {
        present(error as LocalizedError, secondaryButton: secondaryButton)
    }
    
    /// Internal method to construct and present a LocalizedError as an alert.
    ///
    /// Combines failure reason and recovery suggestion into the message for completeness.
    ///
    /// - Parameters:
    ///   - error: The LocalizedError to present.
    ///   - secondaryButton: An optional secondary button.
    private func present(_ error: LocalizedError, secondaryButton: Alert.Button? = nil) {
        let title = error.errorDescription ?? "Error"
        var message = error.failureReason ?? "Something went wrong."
        
        if let recovery = error.recoverySuggestion, !recovery.isEmpty {
            message += "\n\n\(recovery)"
        }
        
        let alert = AppAlert(
            title: title,
            message: message,
            primaryButton: .default(Text("OK")),
            secondaryButton: secondaryButton
        )
        enqueueOrPresent(alert)
    }
    
    // MARK: - Dismiss & Queue Management
    /// Dismisses the current alert and presents the next in queue if available.
    func dismissAlert() {
        logger.info("Alert dismissed")
        if let next = alertQueue.first {
            alertQueue.removeFirst()
            currentAlert = next
        } else {
            currentAlert = nil
        }
    }
    
    /// Enqueues or immediately presents an alert based on current state.
    ///
    /// - Parameter alert: The AppAlert to handle.
    private func enqueueOrPresent(_ alert: AppAlert) {
        if currentAlert != nil {
            logger.info("Alert queued: \(alert.title)")
            alertQueue.append(alert)
        } else {
            logger.info("Alert presented: \(alert.title)")
            currentAlert = alert
        }
    }
}
