import Foundation

/// Countdown strings for the menu bar and popover.
enum TimeFormat {
    /// `24:59`, `1:04:30` past an hour, and `+03:12` for a break in overtime.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(seconds < 0 ? .towardZero : .up))
        let sign = seconds < 0 ? "+" : ""
        let magnitude = abs(total)
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        let secs = magnitude % 60
        if hours > 0 {
            return String(format: "%@%d:%02d:%02d", sign, hours, minutes, secs)
        }
        return String(format: "%@%02d:%02d", sign, minutes, secs)
    }

    /// `1h 15m`, `45m`, or `0m`, for totals.
    static func duration(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    /// `3 sessions · 1h 15m`
    static func summary(sessions: Int, focusSeconds: Int) -> String {
        let noun = sessions == 1 ? "session" : "sessions"
        return "\(sessions) \(noun) · \(duration(focusSeconds))"
    }
}
