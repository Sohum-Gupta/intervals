import Foundation
import Testing
@testable import Intervals

/// A fresh engine with a manual clock, in-memory store and recording sinks.
@MainActor
struct Harness {
    let clock: ManualClock
    let store: InMemorySnapshotStore
    let engine: TimerEngine
    var records: [SessionRecord] { recorder.records }
    var transitions: [TimerTransition] { recorder.transitions }

    private let recorder = Recorder()

    @MainActor
    final class Recorder {
        var records: [SessionRecord] = []
        var transitions: [TimerTransition] = []
    }

    init(
        settings: TimerSettings = TimerSettings(work: 25, shortBreak: 5, longBreak: 15, sessionsBeforeLongBreak: 4),
        start: Date = Date(timeIntervalSince1970: 1_800_000_000),
        store: InMemorySnapshotStore = InMemorySnapshotStore()
    ) {
        clock = ManualClock(start)
        self.store = store
        engine = TimerEngine(clock: clock, settings: settings, store: store, calendar: Self.calendar)
        let recorder = self.recorder
        engine.sessionSink = { recorder.records.append($0) }
        engine.transitionHandler = { recorder.transitions.append($0) }
        engine.refresh()   // what the app does on launch, after wiring the sinks
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    /// Move the clock and let the engine notice, like the 1 Hz tick would.
    func advance(_ seconds: TimeInterval) {
        clock.advance(seconds)
        engine.refresh()
    }

    /// Move the clock without a tick, like sleep or a quit.
    func sleep(_ seconds: TimeInterval) {
        clock.advance(seconds)
    }
}

@MainActor
struct StartPauseResume {
    @Test func startFromIdleRunsWorkForThePlannedLength() {
        let h = Harness()
        let t0 = h.clock.now
        #expect(h.engine.state == .idle(nextPhase: .work))
        #expect(h.engine.remaining == 25 * 60)

        h.engine.start()

        #expect(h.engine.state == .running(phase: .work, startedAt: t0, endsAt: t0.addingTimeInterval(25 * 60)))
        #expect(h.engine.plannedSeconds == 25 * 60)
        #expect(h.engine.progress == 1)
        #expect(h.transitions == [TimerTransition(from: nil, to: .work, at: t0, reason: .started)])
    }

    @Test func remainingIsDerivedFromTheClock() {
        let h = Harness()
        h.engine.start()
        h.advance(10 * 60)
        #expect(h.engine.remaining == 15 * 60)
        #expect(abs(h.engine.progress - 0.6) < 0.0001)
    }

    @Test func pauseStoresRemainingAndNeverExpires() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.advance(5 * 60)
        h.engine.pause()

        #expect(h.engine.state == .paused(phase: .work, startedAt: t0, remaining: 20 * 60))

        h.advance(10 * 60 * 60)
        #expect(h.engine.state == .paused(phase: .work, startedAt: t0, remaining: 20 * 60))
        #expect(h.engine.remaining == 20 * 60)
        #expect(h.records.isEmpty)
    }

    @Test func resumeSetsEndsAtFromNow() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.advance(5 * 60)
        h.engine.pause()
        h.advance(60 * 60)
        h.engine.resume()

        let resumedAt = h.clock.now
        #expect(h.engine.state == .running(phase: .work, startedAt: t0, endsAt: resumedAt.addingTimeInterval(20 * 60)))
        #expect(h.engine.plannedSeconds == 25 * 60)
    }

    @Test func startWhilePausedResumes() {
        let h = Harness()
        h.engine.start()
        h.advance(60)
        h.engine.pause()
        h.engine.start()
        #expect(h.engine.state.isRunning)
        #expect(h.engine.remaining == 24 * 60)
    }

    @Test func toggleCyclesStartPauseResume() {
        let h = Harness()
        h.engine.toggle()
        #expect(h.engine.state.isRunning)
        h.engine.toggle()
        #expect(h.engine.state.isPaused)
        h.engine.toggle()
        #expect(h.engine.state.isRunning)
    }

    @Test func startAndPauseAreNoOpsWhenTheyDoNotApply() {
        let h = Harness()
        h.engine.pause()
        #expect(h.engine.state.isIdle)
        h.engine.resume()
        #expect(h.engine.state.isIdle)
        h.engine.start()
        let running = h.engine.state
        h.engine.start()
        #expect(h.engine.state == running)
    }
}

@MainActor
struct Completion {
    @Test func workCompletionWritesSessionAndStartsShortBreak() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.currentTitle = "Spec review"
        let tag = UUID()
        h.engine.currentTagID = tag
        h.engine.start()
        h.advance(25 * 60)

        let end = t0.addingTimeInterval(25 * 60)
        #expect(h.records == [SessionRecord(
            phase: .work, startedAt: t0, endedAt: end, plannedSeconds: 1500,
            completed: true, title: "Spec review", tagID: tag
        )])
        #expect(h.engine.state == .running(phase: .shortBreak, startedAt: end, endsAt: end.addingTimeInterval(5 * 60)))
        #expect(h.engine.completedWorkInCycle == 1)
        #expect(h.engine.plannedSeconds == 5 * 60)
        #expect(h.transitions.last == TimerTransition(from: .work, to: .shortBreak, at: end, reason: .completed))
    }

    @Test func breaksStartByThemselvesEvenWithAutoStartOff() {
        let h = Harness()
        h.engine.start()
        h.advance(25 * 60)
        #expect(h.engine.phase == .shortBreak)
        #expect(h.engine.state.isRunning)
    }

    @Test func completionAfterSleepIsRecordedAtEndsAtNotNow() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.sleep(2 * 60 * 60)
        h.engine.refresh()

        let end = t0.addingTimeInterval(25 * 60)
        #expect(h.records.count == 1)
        #expect(h.records[0].endedAt == end)
        #expect(h.records[0].completed)
        // The break began at the work's planned end and has long since run over.
        #expect(h.engine.state == .running(phase: .shortBreak, startedAt: end, endsAt: end.addingTimeInterval(5 * 60)))
        #expect(h.engine.isOvertime)
        let overtime: TimeInterval = -5400
        #expect(h.engine.remaining == overtime)
    }

    @Test func pausedWorkNeverCompletes() {
        let h = Harness()
        h.engine.start()
        h.engine.pause()
        h.advance(24 * 60 * 60)
        #expect(h.engine.state.isPaused)
        #expect(h.records.isEmpty)
    }

    @Test func settingsChangesDoNotAlterTheIntervalInProgress() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.engine.settings.workMinutes = 50
        h.advance(25 * 60)
        #expect(h.records.first?.plannedSeconds == 1500)
        #expect(h.records.first?.endedAt == t0.addingTimeInterval(25 * 60))
        #expect(h.engine.phase == .shortBreak)
    }
}

@MainActor
struct Skipping {
    @Test func skipAfterAMinuteWritesIncompleteSessionAndStartsBreak() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.advance(90)
        h.engine.skip()

        #expect(h.records == [SessionRecord(
            phase: .work, startedAt: t0, endedAt: t0.addingTimeInterval(90), plannedSeconds: 1500,
            completed: false, title: "", tagID: nil
        )])
        #expect(h.engine.completedWorkInCycle == 1)
        #expect(h.engine.phase == .shortBreak)
        #expect(h.engine.state.startedAt == t0.addingTimeInterval(90))
        #expect(h.transitions.last?.reason == .skipped)
    }

    @Test func skipUnderAMinuteWritesNothingButStillAdvancesTheCycle() {
        let h = Harness()
        h.engine.start()
        h.advance(59)
        h.engine.skip()
        #expect(h.records.isEmpty)
        #expect(h.engine.completedWorkInCycle == 1)
        #expect(h.engine.phase == .shortBreak)
    }

    @Test func skipPausedWorkUsesElapsedNotWallTime() {
        let h = Harness()
        h.engine.start()
        h.advance(30)
        h.engine.pause()
        h.advance(10 * 60)
        h.engine.skip()
        // Only 30 s of work elapsed, so nothing is written.
        #expect(h.records.isEmpty)
        #expect(h.engine.phase == .shortBreak)
        #expect(h.engine.state.isRunning)
    }

    @Test func skipBreakStartsWorkImmediatelyAndWritesTheGap() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.advance(25 * 60)
        h.advance(2 * 60)
        h.engine.skip()

        let workEnd = t0.addingTimeInterval(25 * 60)
        let skipAt = workEnd.addingTimeInterval(2 * 60)
        #expect(h.records.count == 2)
        #expect(h.records[1] == SessionRecord(
            phase: .shortBreak, startedAt: workEnd, endedAt: skipAt, plannedSeconds: 300,
            completed: false, title: "", tagID: nil
        ))
        #expect(h.engine.state == .running(phase: .work, startedAt: skipAt, endsAt: skipAt.addingTimeInterval(25 * 60)))
    }

    @Test func skipIdleDoesNothing() {
        let h = Harness()
        h.engine.skip()
        #expect(h.engine.state.isIdle)
        #expect(h.records.isEmpty)
        #expect(h.transitions.isEmpty)
    }
}

@MainActor
struct Reset {
    @Test func resetGoesIdleZeroesTheCycleAndWritesNothing() {
        let h = Harness()
        h.engine.start()
        h.advance(25 * 60)
        #expect(h.engine.completedWorkInCycle == 1)
        h.advance(60)
        h.engine.reset()

        #expect(h.engine.state == .idle(nextPhase: .work))
        #expect(h.engine.completedWorkInCycle == 0)
        #expect(h.records.count == 1)
        #expect(h.engine.remaining == 25 * 60)
    }

    @Test func resetMidWorkDiscardsIt() {
        let h = Harness()
        h.engine.start()
        h.advance(20 * 60)
        h.engine.reset()
        #expect(h.records.isEmpty)
        #expect(h.engine.state.isIdle)
    }

    @Test func resetKeepsTitleAndTag() {
        let h = Harness()
        let tag = UUID()
        h.engine.currentTitle = "Thesis"
        h.engine.currentTagID = tag
        h.engine.start()
        h.engine.reset()
        #expect(h.engine.currentTitle == "Thesis")
        #expect(h.engine.currentTagID == tag)
    }
}

@MainActor
struct LongBreakCycle {
    private func completeWork(_ h: Harness) {
        if h.engine.state.isIdle || h.engine.isOvertime { h.engine.start() }
        h.advance(25 * 60)
    }

    @Test func fourthWorkSessionLeadsToALongBreak() {
        let h = Harness()
        for i in 1...3 {
            completeWork(h)
            #expect(h.engine.phase == .shortBreak)
            #expect(h.engine.completedWorkInCycle == i)
            h.advance(5 * 60)   // break ends, overtime begins
        }
        completeWork(h)
        #expect(h.engine.phase == .longBreak)
        #expect(h.engine.plannedSeconds == 15 * 60)
        #expect(h.engine.completedWorkInCycle == 0)

        h.advance(15 * 60)
        h.engine.start()
        #expect(h.engine.phase == .work)
        #expect(h.engine.completedWorkInCycle == 0)
        #expect(h.records.filter { $0.phase == .longBreak }.count == 1)
    }

    @Test func skippedWorkCountsTowardTheLongBreak() {
        let h = Harness(settings: TimerSettings(work: 25, shortBreak: 5, longBreak: 15, sessionsBeforeLongBreak: 2))
        h.engine.start()
        h.advance(30)
        h.engine.skip()
        #expect(h.engine.phase == .shortBreak)
        h.engine.skip()
        h.advance(30)
        h.engine.skip()
        #expect(h.engine.phase == .longBreak)
    }

    @Test func sessionsBeforeLongBreakOfOneAlwaysGivesLongBreaks() {
        let h = Harness(settings: TimerSettings(work: 25, shortBreak: 5, longBreak: 15, sessionsBeforeLongBreak: 1))
        h.engine.start()
        h.advance(25 * 60)
        #expect(h.engine.phase == .longBreak)
    }
}

@MainActor
struct BreakOvertime {
    @Test func breakCountsUpPastItsPlannedEnd() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.advance(25 * 60)
        h.advance(5 * 60)
        #expect(h.engine.isOvertime)
        #expect(h.engine.remaining == 0)
        #expect(h.engine.state.isRunning)

        h.advance(3 * 60 + 12)
        let overtime: TimeInterval = -192
        #expect(h.engine.remaining == overtime)
        #expect(h.engine.progress == 0)
        #expect(h.engine.state == .running(
            phase: .shortBreak,
            startedAt: t0.addingTimeInterval(25 * 60),
            endsAt: t0.addingTimeInterval(30 * 60)
        ))
        #expect(h.records.count == 1)   // only the work session so far
    }

    @Test func startDuringOvertimeWritesTheRealGapAndBeginsWork() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.advance(25 * 60)
        h.advance(5 * 60)
        h.advance(12 * 60)
        h.engine.start()

        let workEnd = t0.addingTimeInterval(25 * 60)
        let startAt = workEnd.addingTimeInterval(17 * 60)
        #expect(h.records.count == 2)
        #expect(h.records[1] == SessionRecord(
            phase: .shortBreak, startedAt: workEnd, endedAt: startAt, plannedSeconds: 300,
            completed: true, title: "", tagID: nil
        ))
        #expect(h.engine.state == .running(phase: .work, startedAt: startAt, endsAt: startAt.addingTimeInterval(25 * 60)))
        #expect(h.transitions.last == TimerTransition(from: .shortBreak, to: .work, at: startAt, reason: .started))
    }

    @Test func breakEndIsAnnouncedExactlyOnceAtThePlannedEnd() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.advance(25 * 60)
        h.advance(4 * 60)
        #expect(h.transitions.count == 2)
        h.advance(60)
        h.advance(60)
        h.advance(60)
        let ended = h.transitions.filter { $0.reason == .breakEnded }
        #expect(ended == [TimerTransition(from: .shortBreak, to: .shortBreak, at: t0.addingTimeInterval(30 * 60), reason: .breakEnded)])
        h.engine.start()
        h.advance(25 * 60)
        h.advance(10 * 60)
        #expect(h.transitions.filter { $0.reason == .breakEnded }.count == 2)
    }

    @Test func breakEndAfterSleepIsAnnouncedAtThePlannedEndNotNow() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.sleep(60 * 60)
        h.engine.refresh()
        #expect(h.transitions.last == TimerTransition(from: .shortBreak, to: .shortBreak, at: t0.addingTimeInterval(30 * 60), reason: .breakEnded))
    }

    @Test func pauseIsIgnoredInOvertime() {
        let h = Harness()
        h.engine.start()
        h.advance(30 * 60 + 1)
        h.engine.pause()
        #expect(h.engine.state.isRunning)
        #expect(h.engine.isOvertime)
        h.engine.toggle()
        #expect(h.engine.phase == .work)
    }

    @Test func breakCanBePausedBeforeItsEndAndResumedLater() {
        let h = Harness()
        h.engine.start()
        h.advance(25 * 60)
        h.advance(60)
        h.engine.pause()
        #expect(h.engine.state == .paused(phase: .shortBreak, startedAt: h.engine.state.startedAt!, remaining: 4 * 60))
        h.advance(60 * 60)
        h.engine.resume()
        #expect(h.engine.remaining == 4 * 60)
        h.advance(4 * 60)
        #expect(h.engine.isOvertime)
    }

    @Test func skipPausedBreakWritesItUpToNow() {
        let h = Harness()
        let t0 = h.clock.now
        h.engine.start()
        h.advance(25 * 60)
        h.engine.pause()
        h.advance(7 * 60)
        h.engine.skip()
        let workEnd = t0.addingTimeInterval(25 * 60)
        #expect(h.records[1].phase == .shortBreak)
        #expect(h.records[1].startedAt == workEnd)
        #expect(h.records[1].endedAt == workEnd.addingTimeInterval(7 * 60))
        #expect(h.records[1].completed == false)
        #expect(h.engine.phase == .work)
    }
}

@MainActor
struct AutoStart {
    private static let settings = TimerSettings(work: 25, shortBreak: 5, longBreak: 15, sessionsBeforeLongBreak: 4, autoStartNext: true)

    @Test func workBeginsByItselfWhenTheBreakEnds() {
        let h = Harness(settings: Self.settings)
        let t0 = h.clock.now
        h.engine.start()
        h.advance(25 * 60)
        h.advance(5 * 60)

        let breakEnd = t0.addingTimeInterval(30 * 60)
        #expect(h.engine.state == .running(phase: .work, startedAt: breakEnd, endsAt: breakEnd.addingTimeInterval(25 * 60)))
        #expect(h.records.count == 2)
        #expect(h.records[1].phase == .shortBreak)
        #expect(h.records[1].startedAt == t0.addingTimeInterval(25 * 60))
        #expect(h.records[1].endedAt == breakEnd)
        #expect(h.records[1].completed)
        #expect(h.transitions.last == TimerTransition(from: .shortBreak, to: .work, at: breakEnd, reason: .autoStarted))
    }

    @Test func autoStartAfterAShortSleepBeginsWorkAtTheBreaksPlannedEnd() {
        let h = Harness(settings: Self.settings)
        let t0 = h.clock.now
        h.engine.start()
        h.advance(25 * 60)
        h.sleep(5 * 60 + 10 * 60)   // sleep through the break and 10 minutes of work
        h.engine.refresh()

        let breakEnd = t0.addingTimeInterval(30 * 60)
        #expect(h.engine.phase == .work)
        #expect(h.engine.state.startedAt == breakEnd)
        #expect(h.engine.remaining == 15 * 60)
    }

    @Test func autoStartDoesNotInventSessionsDuringALongSleep() {
        let h = Harness(settings: Self.settings)
        let t0 = h.clock.now
        h.engine.start()
        h.advance(25 * 60)
        h.sleep(3 * 60 * 60)
        h.engine.refresh()

        // The break would have ended, and the auto-started work would already be
        // over too, so the break stays in overtime rather than fabricating work.
        #expect(h.engine.phase == .shortBreak)
        #expect(h.engine.isOvertime)
        #expect(h.records.count == 1)
        #expect(h.engine.state.startedAt == t0.addingTimeInterval(25 * 60))
    }
}

@MainActor
struct Persistence {
    @Test func snapshotRoundTripsThroughUserDefaults() throws {
        let suite = "com.sohum.intervals.tests.snapshot"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsSnapshotStore(defaults: defaults)
        let clock = ManualClock()
        let tag = UUID()

        let first = TimerEngine(clock: clock, settings: TimerSettings(), store: store)
        first.currentTitle = "Write tests"
        first.currentTagID = tag
        first.start()
        clock.advance(10 * 60)
        first.refresh()
        let expected = first.snapshot

        // Quit and relaunch: a new engine on the same defaults, same clock.
        let second = TimerEngine(clock: clock, settings: TimerSettings(), store: store)
        second.refresh()
        #expect(second.snapshot == expected)
        #expect(second.remaining == 15 * 60)
        #expect(second.currentTitle == "Write tests")
        #expect(second.currentTagID == tag)
    }

    @Test func relaunchAfterTheDeadlineCompletesAtEndsAt() {
        let store = InMemorySnapshotStore()
        var h = Harness(store: store)
        let t0 = h.clock.now
        h.engine.start()
        h.sleep(40 * 60)

        // Relaunch on the same store, 40 minutes later, without ever ticking the first engine.
        h = Harness(start: h.clock.now, store: store)
        let end = t0.addingTimeInterval(25 * 60)
        #expect(h.records.count == 1)
        #expect(h.records.first?.endedAt == end)
        #expect(h.engine.phase == .shortBreak)
        #expect(h.engine.isOvertime)
        let overtime: TimeInterval = -600
        #expect(h.engine.remaining == overtime)
    }

    @Test func pausedStateSurvivesRelaunch() {
        let store = InMemorySnapshotStore()
        var h = Harness(store: store)
        h.engine.start()
        h.advance(3 * 60)
        h.engine.pause()
        h.sleep(8 * 60 * 60)
        h = Harness(start: h.clock.now, store: store)
        #expect(h.engine.state.isPaused)
        #expect(h.engine.remaining == 22 * 60)
    }

    @Test func everyChangeIsSavedImmediately() {
        let store = InMemorySnapshotStore()
        let h = Harness(store: store)
        h.engine.start()
        #expect(store.load()?.state == h.engine.state)
        h.engine.pause()
        #expect(store.load()?.state == h.engine.state)
        h.engine.currentTitle = "Saved"
        #expect(store.load()?.currentTitle == "Saved")
    }

    @Test func timerStateEncodesAsReadableJSON() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = TimerSnapshot(
            state: .running(phase: .work, startedAt: date, endsAt: date.addingTimeInterval(60)),
            completedWorkInCycle: 2, currentTitle: "x", currentTagID: nil, plannedSeconds: 60
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TimerSnapshot.self, from: data)
        #expect(decoded == snapshot)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"running\""))
        #expect(json.contains("\"work\""))
    }
}

@MainActor
struct FreshDay {
    @Test func overtimeBreakAcrossMidnightGoesIdleAndClosesTheGapAtMidnight() {
        // 23:40 local on 2026-11-02 in Los Angeles.
        var components = DateComponents()
        components.year = 2026; components.month = 11; components.day = 2
        components.hour = 23; components.minute = 40
        let lateEvening = Harness.calendar.date(from: components)!
        let h = Harness(start: lateEvening)
        h.engine.start()
        h.advance(25 * 60)              // work ends 00:05, break starts
        h.advance(5 * 60)               // break ends 00:10, overtime
        #expect(h.engine.isOvertime)
        #expect(h.engine.phase == .shortBreak)
        h.engine.reset()

        // Now a break that started before midnight and ran into the next day.
        let h2 = Harness(start: lateEvening.addingTimeInterval(-30 * 60))   // 23:10
        h2.engine.start()
        h2.advance(25 * 60)             // work ends 23:35, break 23:35–23:40
        h2.advance(5 * 60)              // overtime from 23:40
        h2.advance(60 * 60)             // 00:40 next day
        var midnight = DateComponents()
        midnight.year = 2026; midnight.month = 11; midnight.day = 3
        let midnightDate = Harness.calendar.date(from: midnight)!

        #expect(h2.engine.state == .idle(nextPhase: .work))
        #expect(h2.engine.completedWorkInCycle == 0)
        #expect(h2.records.count == 2)
        #expect(h2.records[1].phase == .shortBreak)
        #expect(h2.records[1].endedAt == midnightDate)
        #expect(h2.transitions.last?.reason == .newDay)
    }

    @Test func runningWorkAcrossMidnightIsLeftAlone() {
        var components = DateComponents()
        components.year = 2026; components.month = 11; components.day = 2
        components.hour = 23; components.minute = 50
        let h = Harness(start: Harness.calendar.date(from: components)!)
        h.engine.start()
        h.advance(15 * 60)
        #expect(h.engine.phase == .work)
        #expect(h.engine.state.isRunning)
        #expect(h.engine.remaining == 10 * 60)
    }
}

struct SettingsTests {
    @Test func valuesAreClampedToTheSpecRanges() {
        var settings = TimerSettings(work: 0, shortBreak: 500, longBreak: 15, sessionsBeforeLongBreak: 11)
        #expect(settings.workMinutes == 1)
        #expect(settings.shortBreakMinutes == 120)
        #expect(settings.sessionsBeforeLongBreak == 10)
        settings.longBreakMinutes = -4
        #expect(settings.longBreakMinutes == 1)
    }

    @Test func defaultsMatchTheSpec() {
        let settings = TimerSettings()
        #expect(settings.workMinutes == 25)
        #expect(settings.shortBreakMinutes == 5)
        #expect(settings.longBreakMinutes == 15)
        #expect(settings.sessionsBeforeLongBreak == 4)
        #expect(settings.autoStartNext == false)
    }

    @Test func roundTripsThroughUserDefaults() throws {
        let suite = "com.sohum.intervals.tests.settings"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(TimerSettings.load(from: defaults) == TimerSettings())
        let custom = TimerSettings(work: 50, shortBreak: 10, longBreak: 30, sessionsBeforeLongBreak: 3, autoStartNext: true)
        custom.save(to: defaults)
        #expect(TimerSettings.load(from: defaults) == custom)
    }
}
