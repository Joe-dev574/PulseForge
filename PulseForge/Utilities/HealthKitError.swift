//
//  HealthKitError.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import Foundation


///
/// Conforms to LocalizedError to provide user-friendly descriptions and recovery suggestions.
/// - Important: These errors should be handled gracefully in UI, e.g., via ErrorManager, without exposing technical details to users.
/// - Privacy: Errors do not contain PII; logging should be anonymous.
enum HealthKitError: LocalizedError {
    case healthDataUnavailable
    case authorizationFailed(String)
    case invalidWorkoutDuration
    case workoutSaveFailed(String)
    case heartRateDataUnavailable
    case queryFailed(String)
    case dataNotFound(String)
    case permissionDenied
    case noMaxHeartRateData
    
    /// A localized description of the error for user display.
    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "HealthKit is not available on this device."
        case .authorizationFailed(let message):
            return "Failed to authorize HealthKit: \(message)"
        case .invalidWorkoutDuration:
            return "Workout duration is too short. Must be at least 5 minutes long."
        case .workoutSaveFailed(let message):
            return "Failed to save workout to HealthKit: \(message)"
        case .heartRateDataUnavailable:
            return "Heart rate data is not available."
        case .queryFailed(let message):
            return "HealthKit query failed: \(message)"
        case .dataNotFound(let type):
            return "No \(type) data found in HealthKit."
        case .permissionDenied:
            return "HealthKit permission was denied."
        case .noMaxHeartRateData:
            return "No maximum heart rate data found in HealthKit."
        }
    }
    
    /// Suggestions for recovering from the error, for user guidance.
    var recoverySuggestion: String? {
        switch self {
        case .healthDataUnavailable:
            return "Please ensure your device supports HealthKit."
        case .authorizationFailed:
            return "Please enable HealthKit permissions in the Health app or Settings."
        case .invalidWorkoutDuration, .workoutSaveFailed, .heartRateDataUnavailable:
            return "Please try again or contact support if the issue persists."
        case .queryFailed, .dataNotFound:
            return "Please ensure data exists in the Health app and try again."
        case .permissionDenied:
            return "You can grant permissions in the Settings app under Privacy > Health."
        case .noMaxHeartRateData:
            return "Please ensure data exists in the Health app and try again."
        }
    }
}


