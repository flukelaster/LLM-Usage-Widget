import Foundation

/// Relative-time formatting for reset countdowns and "updated X ago" labels.
enum RelativeTime {
    /// Compact duration like "2h 14m", "5m", "3d 4h", "now".
    static func countdown(to date: Date, from now: Date = Date()) -> String {
        let total = max(0, Int(date.timeIntervalSince(now)))
        if total < 60 { return "now" }
        let minutes = total / 60
        let hours = minutes / 60
        let days = hours / 24
        if days >= 1 {
            let h = hours % 24
            return h > 0 ? "\(days)d \(h)h" : "\(days)d"
        }
        if hours >= 1 {
            let m = minutes % 60
            return m > 0 ? "\(hours)h \(m)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    /// "resets in 2h 14m" for near windows; absolute "resets Tue 9:00 AM" for far ones.
    static func resetLabel(_ date: Date?, from now: Date = Date()) -> String {
        guard let date else { return "no reset info" }
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return "resetting now" }
        if interval < 12 * 3600 {
            return "resets in \(countdown(to: date, from: now))"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return "resets \(formatter.string(from: date))"
    }

    /// "updated just now", "updated 3m ago", "updated 2h ago".
    static func updatedAgo(_ date: Date?, from now: Date = Date()) -> String {
        guard let date else { return "never updated" }
        let secs = max(0, Int(now.timeIntervalSince(date)))
        if secs < 10 { return "updated just now" }
        if secs < 60 { return "updated \(secs)s ago" }
        let minutes = secs / 60
        if minutes < 60 { return "updated \(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "updated \(hours)h ago" }
        return "updated \(hours / 24)d ago"
    }
}

/// Large-number formatting for token counts: 1_284_000 -> "1.28M".
enum NumberFormat {
    static func compact(_ value: Int) -> String {
        let v = Double(value)
        switch abs(v) {
        case 1_000_000_000...:
            return String(format: "%.2fB", v / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.2fM", v / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", v / 1_000)
        default:
            return "\(value)"
        }
    }

    static func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}
