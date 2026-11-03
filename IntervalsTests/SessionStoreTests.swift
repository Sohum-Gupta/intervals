import Foundation
import SwiftData
import Testing
@testable import Intervals

@MainActor
struct SessionStoreTests {
    private func makeStore() throws -> SessionStore {
        SessionStore(container: try SessionStore.makeContainer(inMemory: true))
    }

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func recordsWorkWithTitleAndTag() throws {
        let store = try makeStore()
        let tag = try #require(store.addTag(name: "Deep work"))
        let session = store.record(SessionRecord(
            phase: .work, startedAt: t0, endedAt: t0.addingTimeInterval(1500), plannedSeconds: 1500,
            completed: true, title: "  Spec review ", tagID: tag.id
        ))
        #expect(session.phase == .work)
        #expect(session.title == "Spec review")
        #expect(session.tag?.name == "Deep work")
        #expect(session.durationSeconds == 1500)
        #expect(session.isManual == false)
        #expect(tag.sessions.count == 1)
    }

    @Test func pausedSecondsAreStoredAndExcludedFromFocusTime() throws {
        let store = try makeStore()
        let session = store.record(SessionRecord(
            phase: .work, startedAt: t0, endedAt: t0.addingTimeInterval(5100), plannedSeconds: 1500,
            completed: true, title: "", tagID: nil, pausedSeconds: 3600
        ))
        #expect(session.pausedSeconds == 3600)
        #expect(session.durationSeconds == 1500)
        let summary = store.daySummary(for: t0)
        #expect(summary.focusSeconds == 1500)
    }

    @Test func unknownTagIDRecordsUntagged() throws {
        let store = try makeStore()
        let session = store.record(SessionRecord(
            phase: .work, startedAt: t0, endedAt: t0.addingTimeInterval(60), plannedSeconds: 1500,
            completed: false, title: "", tagID: UUID()
        ))
        #expect(session.tag == nil)
    }

    @Test func daySummaryCountsCompletedWorkAndSumsAllFocusTime() throws {
        let store = try makeStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9))!
        store.record(SessionRecord(phase: .work, startedAt: day, endedAt: day.addingTimeInterval(1500), plannedSeconds: 1500, completed: true, title: "", tagID: nil))
        store.record(SessionRecord(phase: .shortBreak, startedAt: day.addingTimeInterval(1500), endedAt: day.addingTimeInterval(1800), plannedSeconds: 300, completed: true, title: "", tagID: nil))
        store.record(SessionRecord(phase: .work, startedAt: day.addingTimeInterval(1800), endedAt: day.addingTimeInterval(1800 + 600), plannedSeconds: 1500, completed: false, title: "", tagID: nil))
        // Yesterday, must not count.
        store.record(SessionRecord(phase: .work, startedAt: day.addingTimeInterval(-86400), endedAt: day.addingTimeInterval(-86400 + 1500), plannedSeconds: 1500, completed: true, title: "", tagID: nil))

        let summary = store.daySummary(for: day.addingTimeInterval(3600), calendar: calendar)
        #expect(summary.sessions == 1)
        #expect(summary.focusSeconds == 2100)
    }

    @Test func tagNamesAreUniqueIgnoringCase() throws {
        let store = try makeStore()
        #expect(store.addTag(name: "Writing") != nil)
        #expect(store.addTag(name: " writing ") == nil)
        #expect(store.addTag(name: "") == nil)
        let other = try #require(store.addTag(name: "Admin"))
        #expect(store.rename(other, to: "WRITING") == false)
        #expect(other.name == "Admin")
        #expect(store.rename(other, to: "Admin work"))
        #expect(other.name == "Admin work")
        #expect(store.rename(other, to: "admin work"))
    }

    @Test func newTagsGetDistinctColoursAndIncreasingOrder() throws {
        let store = try makeStore()
        let a = try #require(store.addTag(name: "A"))
        let b = try #require(store.addTag(name: "B"))
        #expect(a.colorHex != b.colorHex)
        #expect(b.sortOrder == a.sortOrder + 1)
        #expect(store.tags().map(\.name) == ["A", "B"])
    }

    @Test func deletingATagKeepsItsSessionsUntagged() throws {
        let store = try makeStore()
        let tag = try #require(store.addTag(name: "Temp"))
        let session = store.record(SessionRecord(
            phase: .work, startedAt: t0, endedAt: t0.addingTimeInterval(1500), plannedSeconds: 1500,
            completed: true, title: "Keep me", tagID: tag.id
        ))
        store.delete(tag)
        #expect(store.tags().isEmpty)
        #expect(session.tag == nil)
        #expect(session.title == "Keep me")
        let all = try store.context.fetch(FetchDescriptor<Session>())
        #expect(all.count == 1)
    }

    @Test func changeCountBumpsOnEveryWrite() throws {
        let store = try makeStore()
        #expect(store.changeCount == 0)
        let tag = try #require(store.addTag(name: "X"))
        store.record(SessionRecord(phase: .work, startedAt: t0, endedAt: t0.addingTimeInterval(1), plannedSeconds: 1, completed: true, title: "", tagID: nil))
        store.recolor(tag, to: "#000000")
        #expect(store.changeCount == 3)
    }
}

struct DurationFormatTests {
    @Test func formatsTotals() {
        #expect(TimeFormat.duration(0) == "0m")
        #expect(TimeFormat.duration(59) == "0m")
        #expect(TimeFormat.duration(45 * 60) == "45m")
        #expect(TimeFormat.duration(75 * 60) == "1h 15m")
        #expect(TimeFormat.duration(2 * 3600) == "2h 0m")
        #expect(TimeFormat.summary(sessions: 1, focusSeconds: 1500) == "1 session · 25m")
        #expect(TimeFormat.summary(sessions: 3, focusSeconds: 4500) == "3 sessions · 1h 15m")
    }
}

@MainActor
struct ManualEditTests {
    private func makeStore() throws -> SessionStore {
        SessionStore(container: try SessionStore.makeContainer(inMemory: true))
    }

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func manualSessionIsCompletedWorkFlaggedManual() throws {
        let store = try makeStore()
        let tag = try #require(store.addTag(name: "Reading"))
        let session = store.addManualSession(startedAt: t0, endedAt: t0.addingTimeInterval(40 * 60), title: " Paper ", tag: tag)
        #expect(session.phase == .work)
        #expect(session.completed)
        #expect(session.isManual)
        #expect(session.plannedSeconds == 2400)
        #expect(session.durationSeconds == 2400)
        #expect(session.title == "Paper")
        #expect(session.tag === tag)
    }

    @Test func updateChangesFieldsAndMarksManual() throws {
        let store = try makeStore()
        let session = store.record(SessionRecord(
            phase: .work, startedAt: t0, endedAt: t0.addingTimeInterval(1500), plannedSeconds: 1500,
            completed: true, title: "Draft", tagID: nil
        ))
        #expect(session.isManual == false)
        let tag = try #require(store.addTag(name: "Writing"))
        store.update(session, startedAt: t0.addingTimeInterval(60), endedAt: t0.addingTimeInterval(1800), title: "Final", tag: tag)
        #expect(session.isManual)
        #expect(session.title == "Final")
        #expect(session.tag === tag)
        #expect(session.durationSeconds == 1740)
        #expect(session.plannedSeconds == 1500)
    }

    @Test func updateDropsPausedTimeThatNoLongerFits() throws {
        let store = try makeStore()
        let session = store.record(SessionRecord(
            phase: .work, startedAt: t0, endedAt: t0.addingTimeInterval(5100), plannedSeconds: 1500,
            completed: true, title: "", tagID: nil, pausedSeconds: 3600
        ))
        store.update(session, startedAt: t0, endedAt: t0.addingTimeInterval(1500), title: "", tag: nil)
        #expect(session.pausedSeconds == 0)
        #expect(session.durationSeconds == 1500)
    }
}

@MainActor
struct HistoryStateTests {
    @Test func deleteWaitsForTheToastAndUndoRestores() async throws {
        let store = SessionStore(container: try SessionStore.makeContainer(inMemory: true))
        let history = HistoryState()
        history.store = store
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let a = store.addManualSession(startedAt: t0, endedAt: t0.addingTimeInterval(600))
        let b = store.addManualSession(startedAt: t0.addingTimeInterval(1000), endedAt: t0.addingTimeInterval(1600))

        history.delete(a)
        #expect(history.pendingDeletion === a)
        #expect(try store.context.fetch(FetchDescriptor<Session>()).count == 2)

        history.undoDeletion()
        #expect(history.pendingDeletion == nil)
        #expect(try store.context.fetch(FetchDescriptor<Session>()).count == 2)

        // Deleting another while one is pending commits the first.
        history.delete(a)
        history.delete(b)
        #expect(history.pendingDeletion === b)
        #expect(try store.context.fetch(FetchDescriptor<Session>()).count == 1)

        history.commitPendingDeletion()
        #expect(try store.context.fetch(FetchDescriptor<Session>()).isEmpty)
    }

    @Test func presetsSetTheRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 15))!
        let history = HistoryState()
        history.applyPreset(.week, now: now, calendar: calendar)
        #expect(history.rangeStart == calendar.date(from: DateComponents(year: 2026, month: 10, day: 27))!)
        #expect(history.rangeEnd == now)
        history.applyPreset(.all, now: now, calendar: calendar)
        #expect(history.rangeStart == Date(timeIntervalSince1970: 0))
    }
}
