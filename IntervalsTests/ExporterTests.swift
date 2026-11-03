import Foundation
import SwiftData
import Testing
@testable import Intervals

@MainActor
struct ExporterTests {
    private let zone = TimeZone(identifier: "America/Los_Angeles")!
    private let t0 = Date(timeIntervalSince1970: 1_793_667_600)   // 2026-11-03T01:00:00Z = 2026-11-02 17:00 PST

    private func makeStore() throws -> SessionStore {
        SessionStore(container: try SessionStore.makeContainer(inMemory: true))
    }

    @Test func timestampsCarryTheLocalOffset() {
        #expect(Exporter.timestamp(t0, timeZone: zone) == "2026-11-02T17:00:00-08:00")
    }

    @Test func csvHasTheSpecColumnsAndEscapesFields() throws {
        let store = try makeStore()
        let tag = try #require(store.addTag(name: "Deep work", colorHex: "#4A8FE7"))
        let work = store.record(SessionRecord(
            phase: .work, startedAt: t0, endedAt: t0.addingTimeInterval(1800), plannedSeconds: 1500,
            completed: true, title: "Spec, \"final\" pass", tagID: tag.id, pausedSeconds: 300
        ))
        store.record(SessionRecord(phase: .shortBreak, startedAt: t0.addingTimeInterval(1800), endedAt: t0.addingTimeInterval(2100), plannedSeconds: 300, completed: true, title: "", tagID: nil))

        let csv = Exporter.csv(store.allSessions(), timeZone: zone)
        let lines = csv.split(separator: "\n").map(String.init)
        #expect(lines.count == 3)
        #expect(lines[0] == "id,phase,started_at,ended_at,planned_seconds,paused_seconds,duration_seconds,completed,title,tag,is_manual")
        #expect(lines[1] == "\(work.id.uuidString),work,2026-11-02T17:00:00-08:00,2026-11-02T17:30:00-08:00,1500,300,1500,true,\"Spec, \"\"final\"\" pass\",Deep work,false")
        #expect(lines[2].hasSuffix(",shortBreak,2026-11-02T17:30:00-08:00,2026-11-02T17:35:00-08:00,300,0,300,true,,,false"))
        #expect(csv.hasSuffix("\n"))
    }

    @Test func jsonCarriesTheSameKeysPlusTagColour() throws {
        let store = try makeStore()
        let tag = try #require(store.addTag(name: "Deep work", colorHex: "#4A8FE7"))
        store.record(SessionRecord(phase: .work, startedAt: t0, endedAt: t0.addingTimeInterval(1500), plannedSeconds: 1500, completed: false, title: "Draft", tagID: tag.id))
        store.addManualSession(startedAt: t0.addingTimeInterval(3600), endedAt: t0.addingTimeInterval(5400))

        let data = try Exporter.json(store.allSessions(), timeZone: zone)
        let rows = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(rows.count == 2)
        let first = rows[0]
        #expect(first["phase"] as? String == "work")
        #expect(first["started_at"] as? String == "2026-11-02T17:00:00-08:00")
        #expect(first["completed"] as? Bool == false)
        #expect(first["tag"] as? String == "Deep work")
        #expect(first["tag_color"] as? String == "#4A8FE7")
        #expect(first["duration_seconds"] as? Int == 1500)
        #expect(first["is_manual"] as? Bool == false)
        let second = rows[1]
        #expect(second["tag"] is NSNull)
        #expect(second["is_manual"] as? Bool == true)
        #expect(Set(first.keys) == Set(Exporter.columns + ["tag_color"]))
    }

    @Test func escapeOnlyQuotesWhenNeeded() {
        #expect(Exporter.escape("plain") == "plain")
        #expect(Exporter.escape("a,b") == "\"a,b\"")
        #expect(Exporter.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(Exporter.escape("two\nlines") == "\"two\nlines\"")
    }

    @Test func suggestedFileNameUsesTheLocalDate() {
        #expect(Exporter.suggestedFileName(format: .csv, date: t0, timeZone: zone) == "Intervals 2026-11-02.csv")
        #expect(Exporter.suggestedFileName(format: .json, date: t0, timeZone: TimeZone(identifier: "UTC")!) == "Intervals 2026-11-03.json")
    }
}
