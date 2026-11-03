import Foundation

/// The whole timer in one value. Only `running` has a deadline; `paused` and
/// `idle` wait forever.
enum TimerState: Codable, Equatable, Sendable {
    case idle(nextPhase: Phase)
    case running(phase: Phase, startedAt: Date, endsAt: Date)
    case paused(phase: Phase, startedAt: Date, remaining: TimeInterval)

    /// The phase this state is in, or will be in once started.
    var phase: Phase {
        switch self {
        case .idle(let next): next
        case .running(let phase, _, _), .paused(let phase, _, _): phase
        }
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    /// When the current interval began, for running and paused states.
    var startedAt: Date? {
        switch self {
        case .idle: nil
        case .running(_, let startedAt, _), .paused(_, let startedAt, _): startedAt
        }
    }
}

/// Everything persisted to UserDefaults on every change.
struct TimerSnapshot: Codable, Equatable, Sendable {
    var state: TimerState = .idle(nextPhase: .work)
    /// Work intervals finished (completed or skipped) since the last long break.
    var completedWorkInCycle: Int = 0
    var currentTitle: String = ""
    var currentTagID: UUID?
    /// The interval length, in seconds, when the current interval started.
    /// Kept outside `state` so pause/resume cannot change it.
    var plannedSeconds: Int = 0
    /// Whether the "break is over" alert has fired for the current break.
    var overtimeAnnounced: Bool = false
}

/// Where the snapshot lives. UserDefaults in the app, memory in tests.
protocol SnapshotStore: Sendable {
    func load() -> TimerSnapshot?
    func save(_ snapshot: TimerSnapshot)
}

struct UserDefaultsSnapshotStore: SnapshotStore, @unchecked Sendable {
    // UserDefaults is thread-safe but not marked Sendable.
    static let key = "timerSnapshot"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TimerSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(TimerSnapshot.self, from: data)
    }

    func save(_ snapshot: TimerSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

final class InMemorySnapshotStore: SnapshotStore, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: TimerSnapshot?

    init(_ snapshot: TimerSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func load() -> TimerSnapshot? {
        lock.withLock { snapshot }
    }

    func save(_ snapshot: TimerSnapshot) {
        lock.withLock { self.snapshot = snapshot }
    }
}
