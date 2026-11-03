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
}
