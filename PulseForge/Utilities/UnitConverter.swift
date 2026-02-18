//
//  UnitConverter.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI


enum UnitConverter {
    static let kgToLbs: Double = 2.20462
    static let metersToInches: Double = 39.3701

    static func convertWeightToMetric(_ lbs: Double) -> Double { lbs / kgToLbs }
    static func convertWeightToImperial(_ kg: Double) -> Double { kg * kgToLbs }
    static func convertHeightToImperial(_ meters: Double) -> (feet: Int, inches: Int) {
        let totalInches = meters * metersToInches
        let feet = Int(totalInches / 12)
        var inches = Int((totalInches.truncatingRemainder(dividingBy: 12)).rounded())
        if inches == 12 { inches = 0 }
        return (feet, inches)
    }
    static func convertHeightToMetric(_ feet: Double, _ inches: Double) -> Double {
        ((feet * 12) + inches) * 0.0254
    }
}
enum UnitSystem: String, CaseIterable, Identifiable {
    /// Metric system using kilograms and meters.
    case metric = "Metric"
    /// Imperial system using pounds and feet.
    case imperial = "Imperial"
    
    /// A unique identifier for the unit system.
    var id: String { self.rawValue }
    
    /// The display name for the picker UI.
    var displayName: String {
        switch self {
        case .metric:
            return "Metric"
        case .imperial:
            return "Imperial"
        }
    }
}




