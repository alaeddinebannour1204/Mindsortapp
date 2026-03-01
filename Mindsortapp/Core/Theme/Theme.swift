//
//  Theme.swift
//  Mindsortapp
//
//  Centralized theme for MindSort.
//  Colors use semantic UIKit tokens → automatic dark mode.
//  Typography uses UIFontMetrics → automatic Dynamic Type scaling.
//

import SwiftUI
import UIKit

enum Theme {
    // MARK: - Colors (semantic — auto dark mode + high contrast)

    enum Colors {
        static let background = Color(.systemGroupedBackground)
        static let surface = Color(.secondarySystemGroupedBackground)
        static let text = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
        static let border = Color(.separator)
        static let accent = Color.blue
        static let accentLight = Color(.tertiarySystemFill)
        static let record = Color(.systemRed)
        static let success = Color(.systemGreen)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Typography (Dynamic Type via UIFontMetrics)

    enum Typography {
        static func h1() -> Font {
            Font(UIFontMetrics(forTextStyle: .title1).scaledFont(for: .systemFont(ofSize: 28, weight: .bold)))
        }
        static func h2() -> Font {
            Font(UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 22, weight: .semibold)))
        }
        static func h3() -> Font {
            Font(UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 18, weight: .semibold)))
        }
        static func body() -> Font {
            Font(UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 16, weight: .regular)))
        }
        static func bodySmall() -> Font {
            Font(UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 14, weight: .regular)))
        }
        static func caption() -> Font {
            Font(UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 12, weight: .regular)))
        }
        static func label() -> Font {
            Font(UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .medium)))
        }
    }
}

// MARK: - Color hex initializer (still needed for server-provided colors)

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
