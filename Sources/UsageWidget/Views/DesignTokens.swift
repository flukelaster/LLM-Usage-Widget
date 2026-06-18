import SwiftUI

extension Color {
    /// Build a color from a hex string like "#0F172A" or "0F172A" (optionally with alpha "#RRGGBBAA").
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: UInt64
        switch cleaned.count {
        case 8:
            (r, g, b, a) = (value >> 24 & 0xff, value >> 16 & 0xff, value >> 8 & 0xff, value & 0xff)
        default:
            (r, g, b, a) = (value >> 16 & 0xff, value >> 8 & 0xff, value & 0xff, 255)
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

/// Design tokens — the single place colors, spacing, type, and threshold logic live.
/// Dark-mode-first, tuned to sit on top of native `.ultraThinMaterial`.
enum Theme {
    // Surfaces
    static let cardSurface = Color(hex: "#0F172A").opacity(0.55)
    static let cardStroke = Color.white.opacity(0.08)
    static let barTrack = Color.white.opacity(0.10)
    static let separator = Color.white.opacity(0.06)

    // Text
    static let textPrimary = Color(hex: "#F8FAFC")
    static let textSecondary = Color(hex: "#94A3B8")
    static let textTertiary = Color(hex: "#64748B")

    // Usage thresholds (Apple dark-mode system hues)
    static let safe = Color(hex: "#32D74B")   // < 60%
    static let warn = Color(hex: "#FF9F0A")   // 60–85%
    static let high = Color(hex: "#FF453A")   // > 85%

    /// Color for a normalized utilization 0...1.
    static func threshold(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.60: return safe
        case ..<0.85: return warn
        default: return high
        }
    }

    // Spacing (8pt rhythm, tightened for a compact popover)
    enum Space {
        static let popover: CGFloat = 16
        static let card: CGFloat = 14
        static let cardGap: CGFloat = 10
        static let barGap: CGFloat = 12
        static let tight: CGFloat = 5
    }

    static let cardRadius: CGFloat = 12
    static let barHeight: CGFloat = 8
    static let popoverWidth: CGFloat = 340
}
