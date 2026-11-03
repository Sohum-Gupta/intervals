import Foundation

/// The three kinds of interval. Stored as its raw string in sessions and snapshots.
enum Phase: String, Codable, Sendable {
    case work
    case shortBreak
    case longBreak

    var isBreak: Bool { self != .work }

    /// Name shown above the ring and in lists.
    var displayName: String {
        switch self {
        case .work: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}
