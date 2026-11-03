import Foundation
import Observation
import SwiftData

/// The SwiftData container plus every write the app performs. Views query
/// with `@Query`; the engine and settings go through these methods.
@MainActor
@Observable
final class SessionStore {
    let container: ModelContainer
    /// Bumped after every write so views that fetch by hand can refresh.
    private(set) var changeCount = 0

    var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    /// `~/Library/Application Support/Intervals/Intervals.store` (inside the sandbox container).
    static var storeURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appending(path: "Intervals", directoryHint: .isDirectory).appending(path: "Intervals.store")
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Session.self, Tag.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            let url = storeURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            configuration = ModelConfiguration(schema: schema, url: url)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: Sessions

    /// Store an interval the engine finished.
    @discardableResult
    func record(_ record: SessionRecord, now: Date = Date()) -> Session {
        let session = Session(
            phase: record.phase,
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            plannedSeconds: record.plannedSeconds,
            completed: record.completed,
            pausedSeconds: record.pausedSeconds,
            title: record.title.trimmingCharacters(in: .whitespacesAndNewlines),
            tag: tag(id: record.tagID),
            isManual: false,
            createdAt: now
        )
        context.insert(session)
        commit()
        return session
    }

    func delete(_ session: Session) {
        context.delete(session)
        commit()
    }

    /// Completed work sessions and total focus time for the calendar day containing `date`.
    func daySummary(for date: Date, calendar: Calendar = .current) -> (sessions: Int, focusSeconds: Int) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        let work = Phase.work.rawValue
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.phaseRaw == work && $0.startedAt >= start && $0.startedAt < end }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        let completed = sessions.filter(\.completed).count
        let seconds = sessions.reduce(0.0) { $0 + $1.durationSeconds }
        return (completed, Int(seconds))
    }

    // MARK: Tags

    func tags() -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func tag(id: UUID?) -> Tag? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    /// Whether `name` is free, ignoring case and surrounding whitespace, apart from `tag` itself.
    func isNameAvailable(_ name: String, excluding tag: Tag? = nil) -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        return !tags().contains { $0 !== tag && $0.name.caseInsensitiveCompare(cleaned) == .orderedSame }
    }

    /// Adds a tag, or returns nil when the name is empty or taken.
    @discardableResult
    func addTag(name: String, colorHex: String? = nil) -> Tag? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNameAvailable(cleaned) else { return nil }
        let existing = tags()
        let tag = Tag(
            name: cleaned,
            colorHex: colorHex ?? TagColor.nextHex(existing: existing.map(\.colorHex)),
            sortOrder: (existing.map(\.sortOrder).max() ?? -1) + 1
        )
        context.insert(tag)
        commit()
        return tag
    }

    /// Renames a tag; returns false and leaves it unchanged if the name is taken.
    @discardableResult
    func rename(_ tag: Tag, to name: String) -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned != tag.name else { return true }
        guard isNameAvailable(cleaned, excluding: tag) else { return false }
        tag.name = cleaned
        commit()
        return true
    }

    func recolor(_ tag: Tag, to hex: String) {
        tag.colorHex = hex
        commit()
    }

    /// Deletes the tag; its sessions keep their rows and lose the tag.
    func delete(_ tag: Tag) {
        for session in tag.sessions { session.tag = nil }
        context.delete(tag)
        commit()
    }

    // MARK: -

    func commit() {
        try? context.save()
        changeCount += 1
    }
}
