//
//  Category.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI
import SwiftData
internal import HealthKit
import OSLog

/// Defines the color, HealthKit activity type, and MET value for workout categories.
/// Conforms to Codable for SwiftData persistence.
///
/// This enum maps workout categories to visual colors, HealthKit types, and MET values for energy estimation.
/// - Note: Colors are defined in the asset catalog using the rawValue as the name.
/// - Important: MET values are approximate averages; for precise calculations, consider user-specific factors.

enum CategoryColor: String, Codable, CaseIterable {
    /// Cardio-based workouts (e.g., mixed cardio).
    case CARDIO
    /// Cross-training workouts.
    case CROSSTRAIN
    /// Cycling workouts.
    case CYCLING
    /// Grappling or martial arts workouts.
    case GRAPPLING
    /// High-intensity interval training workouts.
    case HIIT
    /// Hiking workouts.
    case HIKING
    /// Jump Rope workouts.
    case JUMPROPE
    /// Pilates workouts.
    case PILATES
    /// Power-based strength workouts.
    case POWER
    /// Recovery or flexibility workouts.
    case RECOVERY
    /// Rowing workouts.
    case ROWING
    /// Running workouts.
    case RUN
    /// Stretching workouts.
    case STRETCH
    /// Strength training workouts.
    case STRENGTH
    /// Swimming workouts.
    case SWIMMING
    /// Test or miscellaneous workouts.
    case TEST
    /// Walking workouts.
    case WALK
    /// Yoga workouts.
    case YOGA
    
    /// The SwiftUI color associated with the category, defined in the asset catalog.
    var color: Color {
        Color(rawValue)
    }
    
    /// The HealthKit workout activity type corresponding to the category.
    var hkActivityType: HKWorkoutActivityType {
        switch self {
        case .CARDIO: .mixedCardio
        case .CROSSTRAIN: .crossTraining
        case .CYCLING: .cycling
        case .GRAPPLING: .martialArts
        case .HIIT: .highIntensityIntervalTraining
        case .HIKING: .hiking
        case .JUMPROPE: .jumpRope
        case .PILATES: .pilates
        case .POWER: .traditionalStrengthTraining
        case .RECOVERY: .flexibility
        case .ROWING: .rowing
        case .RUN: .running
        case .STRETCH: .flexibility
        case .STRENGTH: .traditionalStrengthTraining
        case .SWIMMING: .swimming
        case .TEST: .other
        case .WALK: .walking
        case .YOGA: .yoga
        }
    }
    
    /// The MET (Metabolic Equivalent of Task) value for the category.
    /// Used for estimating energy expenditure.
    /// - Note: These are standard averages; actual MET may vary by intensity and user profile.
    var metValue: Double {
        switch self {
        case .CARDIO: 8.0
        case .CROSSTRAIN: 7.0
        case .CYCLING: 6.8
        case .GRAPPLING: 6.0
        case .HIIT: 10.0
        case .HIKING: 7.0
        case .JUMPROPE: 10.0
        case .PILATES: 3.5
        case .POWER: 8.0
        case .RECOVERY: 2.5
        case .ROWING: 7.0
        case .RUN: 8.0
        case .STRETCH: 2.5
        case .STRENGTH: 6.0
        case .SWIMMING: 7.0
        case .TEST: 5.0
        case .WALK: 3.5
        case .YOGA: 3.0
        }
    }
}

/// A persistent model representing a workout category, conforming to SwiftData’s @Model.
///
/// This class stores category details for workouts, including name, icon, and color.
/// It maintains a one-to-many relationship with Workout entities.
/// - Important: Category names must be unique and non-empty; enforced in init.
/// - Privacy: No user-identifiable data stored here; categories are app-defined.
@Model
final class Category: Identifiable, Equatable {
    /// The unique name of the category.
    var categoryName: String = "STRENGTH"
    
    /// The SF Symbol name for the category icon.
    var symbol: String = "running"
    
    /// The raw string value for the category color, stored directly in SwiftData as a basic type.
    var categoryColorRaw: String = "STRENGTH"
    
    /// Computed property for the category color enum, with fallback to .STRENGTH on invalid raw values.
    var categoryColor: CategoryColor {
        get {
            CategoryColor(rawValue: categoryColorRaw) ?? .STRENGTH
        }
        set {
            categoryColorRaw = newValue.rawValue
        }
    }
    
    // Inverse relationship to Workouts (one-to-many)
    @Relationship(deleteRule: .nullify, inverse: \Workout.category)
    var workouts: [Workout]? = []
    
    /// Logger for debugging and monitoring category operations.
    @Transient
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier
            ?? "com.tnt.PulseForge.default.subsystem",
        category: "Category"
    )
    
    /// Initializes a new category with the specified properties.
    /// - Parameters:
    ///   - categoryName: The unique name of the category.
    ///   - symbol: The SF Symbol name for the category icon.
    ///   - categoryColor: The color and HealthKit activity type (defaults to .STRENGTH).
    /// - Important: Throws a fatalError if name is empty after trimming.
    init(
        categoryName: String,
        symbol: String,
        categoryColor: CategoryColor = .STRENGTH
    ) {
        let trimmedName = categoryName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedName.isEmpty else {
            logger.error("Attempted to create category with empty name")
            fatalError("Category name cannot be empty or whitespace-only")
        }
        self.categoryName = trimmedName
        self.symbol = symbol
        self.categoryColor = categoryColor  // Uses setter to update raw value
    }
    
    // Equatable conformance for comparisons (e.g., in filters)
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.categoryName == rhs.categoryName
    }
}

