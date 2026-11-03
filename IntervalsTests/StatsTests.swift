import Foundation
import SwiftData
import Testing
@testable import Intervals

@MainActor
struct StatsTests {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.firstWeekday = 2
        return c
    }()

    private func date(_ day: Int, _ hour: Int, month: Int = 11) -> Date {
        Self.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func makeStore() throws -> SessionStore {
        SessionStore(container: try SessionStore.makeContainer(inMemory: true))
    }

    private func work(_ store: SessionStore, start: Date, minutes: Int, completed: Bool = true, paused: Int = 0, tag: UUID? = nil) {
        store.record(SessionRecord(
            phase: .work, startedAt: start, endedAt: start.addingTimeInterval(Double(minutes * 60 + paused)),
            plannedSeconds: 1500, completed: completed, title: "", tagID: tag, pausedSeconds: paused
        ))
    }

    @Test func summaryCountsCompletedSkippedAndFocusMinusPauses() throws {
        let store = try makeStore()
        work(store, start: date(2, 9), minutes: 25)
        work(store, start: date(2, 10), minutes: 10, completed: false)
        work(store, start: date(2, 11), minutes: 25, paused: 600)
        store.record(SessionRecord(phase: .shortBreak, startedAt: date(2, 12), endedAt: date(2, 13), plannedSeconds: 300, completed: true, title: "", tagID: nil))
        let summary = Stats.summary(of: store.allSessions())
        #expect(summary == Stats.Summary(sessions: 2, skipped: 1, focusSeconds: 60 * 60))
    }

    @Test func rangesFollowTheLocalCalendar() {
        let now = date(2, 15)   // Monday 2 Nov 2026
        let today = Stats.Range.today.interval(containing: now, calendar: Self.calendar)
        #expect(today.start == date(2, 0))
        #expect(today.end == date(3, 0))
        let week = Stats.Range.week.interval(containing: now, calendar: Self.calendar)
        #expect(week.start == date(2, 0))
        #expect(week.end == date(9, 0))
        let month = Stats.Range.month.interval(containing: now, calendar: Self.calendar)
        #expect(month.start == date(1, 0))
        #expect(month.end == date(1, 0, month: 12))
    }

    @Test func dailyIsZeroFilledOldestFirstAndIgnoresOutsideDays() throws {
        let store = try makeStore()
        work(store, start: date(2, 9), minutes: 25)
        work(store, start: date(2, 14), minutes: 25)
        work(store, start: date(1, 9), minutes: 10)
        work(store, start: date(19, 9, month: 10), minutes: 99)   // 14 days before 2 Nov: outside
        work(store, start: date(20, 9, month: 10), minutes: 5)    // first day in range
        let days = Stats.daily(store.allSessions(), days: 14, endingOn: date(2, 15), calendar: Self.calendar)
        #expect(days.count == 14)
        #expect(days.first?.day == date(20, 0, month: 10))
        #expect(days.first?.focusSeconds == 300)
        #expect(days.last?.day == date(2, 0))
        #expect(days.last?.focusSeconds == 3000)
        #expect(days[12].focusSeconds == 600)
        #expect(days[5].focusSeconds == 0)
    }

    @Test func perTagSortsByFocusWithUntaggedLast() throws {
        let store = try makeStore()
        let a = try #require(store.addTag(name: "Admin"))
        let b = try #require(store.addTag(name: "Writing"))
        work(store, start: date(2, 9), minutes: 25, tag: b.id)
        work(store, start: date(2, 10), minutes: 25, tag: b.id)
        work(store, start: date(2, 11), minutes: 5, completed: false, tag: a.id)
        work(store, start: date(2, 12), minutes: 50)
        let rows = Stats.perTag(store.allSessions())
        #expect(rows.map(\.name) == ["Writing", "Admin", "Untagged"])
        #expect(rows[0].summary == Stats.Summary(sessions: 2, skipped: 0, focusSeconds: 3000))
        #expect(rows[1].summary == Stats.Summary(sessions: 0, skipped: 1, focusSeconds: 300))
        #expect(rows[2].tagID == nil)
        #expect(rows[0].colorHex == b.colorHex)
    }

    @Test func storeRangeFetchIsHalfOpenAndWorkOnly() throws {
        let store = try makeStore()
        work(store, start: date(1, 23), minutes: 25)
        work(store, start: date(2, 0), minutes: 25)
        work(store, start: date(3, 0), minutes: 25)
        store.record(SessionRecord(phase: .longBreak, startedAt: date(2, 12), endedAt: date(2, 13), plannedSeconds: 900, completed: true, title: "", tagID: nil))
        let sessions = store.workSessions(from: date(2, 0), to: date(3, 0))
        #expect(sessions.count == 1)
        #expect(sessions.first?.startedAt == date(2, 0))
    }
}
