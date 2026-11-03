import Foundation
import SwiftData

/// One recorded interval. Work sessions carry the title and tag; a break is
/// the real gap between one work session's end and the next one's start.
@Model
final class Session {
    @Attribute(.unique) var id: UUID
    /// `Phase.rawValue`, stored as a string so predicates can filter on it.
    var phaseRaw: String
    var startedAt: Date
    var endedAt: Date
    /// The interval length when it started.
    var plannedSeconds: Int
    /// false = skipped early.
    var completed: Bool
    /// Seconds spent paused, excluded from focus time. 0 for breaks and manual sessions.
    var pausedSeconds: Int = 0
    var title: String
    var tag: Tag?
    /// true when added or edited by hand.
    var isManual: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        phase: Phase,
        startedAt: Date,
        endedAt: Date,
        plannedSeconds: Int,
        completed: Bool,
        pausedSeconds: Int = 0,
        title: String = "",
        tag: Tag? = nil,
        isManual: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.phaseRaw = phase.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.completed = completed
        self.pausedSeconds = pausedSeconds
        self.title = title
        self.tag = tag
        self.isManual = isManual
        self.createdAt = createdAt
    }

    var phase: Phase {
        get { Phase(rawValue: phaseRaw) ?? .work }
        set { phaseRaw = newValue.rawValue }
    }

    /// Wall-clock span minus pauses. This is what focus time sums.
    var durationSeconds: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt) - TimeInterval(pausedSeconds)) }
}
