//
//  Theme.swift
//  Mindsortapp
//
//  Centralized theme for MindSort.
//

import SwiftUI

enum Theme {
    enum Colors {
        static let background = Color(hex: "FAFAFA")
        static let surface = Color(hex: "FFFFFF")
        static let text = Color(hex: "1A1A1A")
        static let textSecondary = Color(hex: "6B6B6B")
        static let textTertiary = Color(hex: "9E9E9E")
        static let border = Color(hex: "F0F0F0")
        static let accent = Color(hex: "1A1A1A")
        static let accentLight = Color(hex: "F5F5F5")
        static let record = Color(hex: "FF3B30")
        static let success = Color(hex: "34C759")
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Typography {
        static func h1() -> Font { .system(size: 28, weight: .bold) }
        static func h2() -> Font { .system(size: 22, weight: .semibold) }
        static func h3() -> Font { .system(size: 18, weight: .semibold) }
        static func body() -> Font { .system(size: 16, weight: .regular) }
        static func bodySmall() -> Font { .system(size: 14, weight: .regular) }
        static func caption() -> Font { .system(size: 12, weight: .regular) }
        static func label() -> Font { .system(size: 13, weight: .medium) }
    }
}

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
