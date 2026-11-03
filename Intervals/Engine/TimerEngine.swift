import Foundation
import Observation

/// The timer, as a pure state machine over wall-clock timestamps.
///
/// Remaining time is always `endsAt - now`. Nothing here counts; `refresh()`
/// just re-reads the clock and settles any deadline that has passed, so
/// sleeping, quitting or crashing never loses the current interval (F5).
///
/// No SwiftUI in this file. The clock, the snapshot store and the two sinks are
/// injected so tests can jump time and inspect what would have been written.
@MainActor
@Observable
final class TimerEngine {
    /// Time of the last evaluation. Views read this so a 1 Hz `refresh()` redraws them.
    private(set) var now: Date

    /// Everything persisted. Every mutation is saved immediately.
    private(set) var snapshot: TimerSnapshot {
        didSet { if snapshot != oldValue { store.save(snapshot) } }
    }

    /// Changing settings never alters the interval already in progress.
    var settings: TimerSettings

    /// Receives every finished interval. Milestone 3 writes these to SwiftData.
    var sessionSink: (@MainActor (SessionRecord) -> Void)?

    /// Receives every phase change, so the app can notify and play a sound.
    var transitionHandler: (@MainActor (TimerTransition) -> Void)?

    @ObservationIgnored private let clock: any WallClock
    @ObservationIgnored private let store: any SnapshotStore
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var ticker: Timer?

    /// A work interval skipped before this many seconds leaves no record.
    static let minimumRecordedWork: TimeInterval = 60

    init(
        clock: any WallClock = SystemClock(),
        settings: TimerSettings = .load(),
        store: any SnapshotStore = UserDefaultsSnapshotStore(),
        calendar: Calendar = .current
    ) {
        self.clock = clock
        self.store = store
        self.calendar = calendar
        self.settings = settings
        self.now = clock.now
        self.snapshot = store.load() ?? TimerSnapshot()
        // Deliberately no evaluate() here: the app attaches `sessionSink` and
        // `transitionHandler` first, then calls `refresh()`, so an interval that
        // ended while the app was closed is recorded rather than lost.
    }

    // MARK: - Derived values

    var state: TimerState { snapshot.state }
    var phase: Phase { snapshot.state.phase }
    var completedWorkInCycle: Int { snapshot.completedWorkInCycle }

    var currentTitle: String {
        get { snapshot.currentTitle }
        set { snapshot.currentTitle = newValue }
    }

    var currentTagID: UUID? {
        get { snapshot.currentTagID }
        set { snapshot.currentTagID = newValue }
    }

    /// Length of the interval in progress, or of the next one when idle.
    var plannedSeconds: Int {
        if case .idle(let next) = snapshot.state { return settings.seconds(for: next) }
        return snapshot.plannedSeconds
    }

    /// Seconds left at `date`. Negative once a break runs past its planned end.
    func remaining(at date: Date) -> TimeInterval {
        switch snapshot.state {
        case .idle(let next): settings.length(of: next)
        case .running(_, _, let endsAt): endsAt.timeIntervalSince(date)
        case .paused(_, _, let remaining): remaining
        }
    }

    /// Seconds left as of the last `refresh()`.
    var remaining: TimeInterval { remaining(at: now) }

    /// A break whose planned length has passed and is now counting up.
    var isOvertime: Bool {
        if case .running(let phase, _, let endsAt) = snapshot.state, phase.isBreak {
            return now >= endsAt
        }
        return false
    }

    /// Fraction of the interval still to go, 0...1, for the ring.
    func progress(at date: Date) -> Double {
        let planned = Double(plannedSeconds)
        guard planned > 0 else { return 0 }
        return (remaining(at: date) / planned).clamped(to: 0...1)
    }

    var progress: Double { progress(at: now) }

    // MARK: - Commands

    /// Start from idle, resume if paused, or begin work from a break in overtime.
    func start() {
        refresh()
        switch snapshot.state {
        case .idle(let next):
            begin(next, at: now, reason: .started, from: nil)
        case .paused:
            resume()
        case .running(let phase, _, let endsAt) where phase.isBreak && now >= endsAt:
            closeBreakAndStartWork(at: now, reason: .started)
        case .running:
            break
        }
    }

    func pause() {
        refresh()
        guard case .running(let phase, let startedAt, let endsAt) = snapshot.state, now < endsAt else { return }
        snapshot.state = .paused(phase: phase, startedAt: startedAt, remaining: endsAt.timeIntervalSince(now))
    }

    func resume() {
        refresh()
        guard case .paused(let phase, let startedAt, let remaining) = snapshot.state else { return }
        snapshot.state = .running(phase: phase, startedAt: startedAt, endsAt: now.addingTimeInterval(remaining))
    }

    /// Space in the popover: start, pause or resume depending on state.
    func toggle() {
        refresh()
        switch snapshot.state {
        case .idle, .paused: start()
        case .running where isOvertime: start()
        case .running: pause()
        }
    }

    /// End the current interval early. Short work (< 60 s) leaves no record but
    /// still counts toward the long break. Skipping a break starts work now.
    func skip() {
        refresh()
        switch snapshot.state {
        case .idle:
            return
        case .running(let phase, let startedAt, _), .paused(let phase, let startedAt, _):
            if phase.isBreak {
                closeBreakAndStartWork(at: now, reason: .skipped)
            } else {
                let elapsed = Double(snapshot.plannedSeconds) - remaining
                if elapsed >= Self.minimumRecordedWork {
                    record(phase: .work, startedAt: startedAt, endedAt: now, completed: false)
                }
                finishWork(at: now, reason: .skipped)
            }
        }
    }

    /// Discard the current interval and the cycle. Writes nothing.
    func reset() {
        refresh()
        snapshot.state = .idle(nextPhase: .work)
        snapshot.completedWorkInCycle = 0
        snapshot.plannedSeconds = 0
        snapshot.overtimeAnnounced = false
    }

    /// Re-read the clock and settle any deadline that has passed. Called at
    /// 1 Hz by the UI, on launch, and on wake from sleep.
    func refresh() {
        evaluate()
    }

    // MARK: - Ticking

    /// Drive `refresh()` once a second on the main run loop. Display only.
    func startTicking() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { self.refresh() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    // MARK: - State machine

    private func evaluate() {
        now = clock.now
        // Settle deadlines in order. Each pass handles one transition; the
        // loop ends when the state has no deadline in the past.
        var steps = 0
        while steps < 64 {
            steps += 1
            guard case .running(let phase, let startedAt, let endsAt) = snapshot.state, now >= endsAt else { return }

            if phase == .work {
                // Complete as if it fired at endsAt, so the session has the right end.
                record(phase: .work, startedAt: startedAt, endedAt: endsAt, completed: true)
                finishWork(at: endsAt, reason: .completed)
                continue
            }

            // A break past its planned end.
            if settings.autoStartNext, endsAt.addingTimeInterval(settings.length(of: .work)) > now {
                // Work begins by itself at the break's planned end. If that work
                // would already be over too (a long sleep), nobody was here to do
                // it, so the break stays in overtime instead of inventing sessions.
                closeBreakAndStartWork(at: endsAt, reason: .autoStarted)
                continue
            }

            if !calendar.isDate(now, inSameDayAs: startedAt) {
                // A fresh day: close the gap at local midnight and go idle.
                let midnight = calendar.startOfDay(for: now)
                let end = max(midnight, endsAt)
                record(phase: phase, startedAt: startedAt, endedAt: end, completed: true)
                snapshot.state = .idle(nextPhase: .work)
                snapshot.completedWorkInCycle = 0
                snapshot.plannedSeconds = 0
                transitionHandler?(TimerTransition(from: phase, to: nil, at: end, reason: .newDay))
                return
            }

            // Overtime: keep running and count up until Start. Announce once.
            if !snapshot.overtimeAnnounced {
                snapshot.overtimeAnnounced = true
                transitionHandler?(TimerTransition(from: phase, to: phase, at: endsAt, reason: .breakEnded))
            }
            return
        }
    }

    private func begin(_ phase: Phase, at date: Date, reason: TimerTransition.Reason, from previous: Phase?) {
        let seconds = settings.seconds(for: phase)
        snapshot.plannedSeconds = seconds
        snapshot.overtimeAnnounced = false
        snapshot.state = .running(phase: phase, startedAt: date, endsAt: date.addingTimeInterval(TimeInterval(seconds)))
        transitionHandler?(TimerTransition(from: previous, to: phase, at: date, reason: reason))
    }

    /// Advance the cycle after a completed or skipped work interval and start the break that follows.
    private func finishWork(at date: Date, reason: TimerTransition.Reason) {
        snapshot.completedWorkInCycle += 1
        let next: Phase
        if snapshot.completedWorkInCycle >= settings.sessionsBeforeLongBreak {
            next = .longBreak
            snapshot.completedWorkInCycle = 0
        } else {
            next = .shortBreak
        }
        begin(next, at: date, reason: reason, from: .work)
    }

    /// Write the break as the real gap since work ended, then start work.
    private func closeBreakAndStartWork(at date: Date, reason: TimerTransition.Reason) {
        switch snapshot.state {
        case .running(let phase, let startedAt, let endsAt) where phase.isBreak:
            record(phase: phase, startedAt: startedAt, endedAt: date, completed: date >= endsAt)
            begin(.work, at: date, reason: reason, from: phase)
        case .paused(let phase, let startedAt, let remaining) where phase.isBreak:
            record(phase: phase, startedAt: startedAt, endedAt: date, completed: remaining <= 0)
            begin(.work, at: date, reason: reason, from: phase)
        default:
            return
        }
    }

    private func record(phase: Phase, startedAt: Date, endedAt: Date, completed: Bool) {
        sessionSink?(SessionRecord(
            phase: phase,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedSeconds: snapshot.plannedSeconds,
            completed: completed,
            title: phase == .work ? snapshot.currentTitle : "",
            tagID: phase == .work ? snapshot.currentTagID : nil
        ))
    }
}
