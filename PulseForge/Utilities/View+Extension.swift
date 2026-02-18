//
//  View+Extension.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/18/26.
//

import SwiftUI

/// Custom View Extensions
extension View {
    /// Custom Spacers
    @ViewBuilder
    func hSpacing(_ alignment: Alignment) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: alignment)
    }
    
    @ViewBuilder
    func vSpacing(_ alignment: Alignment) -> some View {
        self
            .frame(maxHeight: .infinity, alignment: alignment)
    }
    
    /// Checking Two dates are same
    func isSameDate(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }
}

enum UIConstants {
    static let profileImageSize = CGSize(width: 512, height: 512)
    static let gridItemSize: CGFloat = 120
    static let maxImageSizeBytes: Int = 5 * 1024 * 1024 // 5MB
    static let healthDataFetchTimeout: TimeInterval = 5.0
}

    /// Date Extensions Needed for Building UI
extension Date {
    /// Custom Date Format
    func format(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        
        return formatter.string(from: self)
    }
    
    var dateComponents: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: self)
    }
    
}

// MARK:  Extension to support hex color conversion for theme customization.
extension Color {
    /// Initializes a color from a hex string (e.g., "#FF0000").
    /// - Parameter hex: The hex string, with or without "#".
    /// - Returns: A `Color` if the hex string is valid, or nil otherwise.
    init?(hex: String) {
        let r, g, b: Double
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        
        guard hexString.count == 6, let hexNumber = UInt64(hexString, radix: 16) else { return nil }
        
        r = Double((hexNumber >> 16) & 0xFF) / 255.0
        g = Double((hexNumber >> 8) & 0xFF) / 255.0
        b = Double(hexNumber & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    /// Converts the color to a hex string (e.g., "#FF0000").
    /// - Returns: The hex string representation, or "#000000" if conversion fails.
    var hex: String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}




