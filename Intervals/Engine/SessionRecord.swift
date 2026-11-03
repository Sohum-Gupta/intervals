import Foundation

/// A finished interval as the engine reports it. Milestone 3 turns these into
/// SwiftData `Session` rows; until then the engine just hands them out.
struct SessionRecord: Equatable, Sendable {
    var phase: Phase
    var startedAt: Date
    var endedAt: Date
    var plannedSeconds: Int
    /// For work: finished its planned length. For breaks: ran at least its planned length.
    var completed: Bool
    var title: String
    var tagID: UUID?

    var durationSeconds: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}

/// A phase change the UI may want to announce with a notification or sound.
struct TimerTransition: Equatable, Sendable {
    enum Reason: Sendable {
        /// The interval reached its planned end.
        case completed
        /// The user skipped the interval.
        case skipped
        /// A break reached its planned end and is now in overtime. Fires once
        /// per break; `from` and `to` are the same phase.
        case breakEnded
        /// The user pressed Start (from idle or from a break in overtime).
        case started
        /// Work began by itself because auto-start is on.
        case autoStarted
        /// A new calendar day began during an overtime break.
        case newDay
    }

    var from: Phase?
    var to: Phase?
    var at: Date
    var reason: Reason
}
