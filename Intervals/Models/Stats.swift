import Foundation

/// Pure stats over work sessions. Nothing is pre-aggregated; callers pass the
/// sessions for the range they care about.
enum Stats {
    struct Summary: Equatable, Sendable {
        var sessions: Int = 0        // completed work sessions
        var skipped: Int = 0
        var focusSeconds: Int = 0    // all work sessions, completed or skipped
    }

    struct Day: Identifiable, Equatable, Sendable {
        var day: Date
        var focusSeconds: Int
        var id: Date { day }
        var focusMinutes: Double { Double(focusSeconds) / 60 }
    }

    struct TagRow: Identifiable, Equatable, Sendable {
        var tagID: UUID?           // nil = untagged
        var name: String
        var colorHex: String?
        var summary: Summary
        var id: String { tagID?.uuidString ?? "untagged" }
    }

    enum Range: String, CaseIterable, Identifiable, Sendable {
        case today = "Today", week = "This week", month = "This month"
        var id: String { rawValue }

        /// Half-open interval of start dates, in local time.
        func interval(containing date: Date, calendar: Calendar = .current) -> Range.Interval {
            let start: Date
            let end: Date
            switch self {
            case .today:
                start = calendar.startOfDay(for: date)
                end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
            case .week:
                let week = calendar.dateInterval(of: .weekOfYear, for: date)
                start = week?.start ?? calendar.startOfDay(for: date)
                end = week?.end ?? date
            case .month:
                let month = calendar.dateInterval(of: .month, for: date)
                start = month?.start ?? calendar.startOfDay(for: date)
                end = month?.end ?? date
            }
            return Interval(start: start, end: end)
        }

        struct Interval: Equatable, Sendable {
            var start: Date
            var end: Date
            func contains(_ date: Date) -> Bool { date >= start && date < end }
        }
    }

    static func summary(of sessions: [Session]) -> Summary {
        var result = Summary()
        for session in sessions where session.phase == .work {
            if session.completed { result.sessions += 1 } else { result.skipped += 1 }
            result.focusSeconds += Int(session.durationSeconds.rounded())
        }
        return result
    }

    /// Focus seconds per calendar day for the `count` days ending on `end`'s day, zero-filled, oldest first.
    static func daily(_ sessions: [Session], days count: Int = 14, endingOn end: Date, calendar: Calendar = .current) -> [Day] {
        let last = calendar.startOfDay(for: end)
        guard let first = calendar.date(byAdding: .day, value: -(count - 1), to: last) else { return [] }
        var totals: [Date: Int] = [:]
        for session in sessions where session.phase == .work {
            let day = calendar.startOfDay(for: session.startedAt)
            guard day >= first, day <= last else { continue }
            totals[day, default: 0] += Int(session.durationSeconds.rounded())
        }
        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            return Day(day: day, focusSeconds: totals[day] ?? 0)
        }
    }

    /// One row per tag with any work in `sessions`, most focus first, plus "Untagged" last if present.
    static func perTag(_ sessions: [Session]) -> [TagRow] {
        var rows: [String: TagRow] = [:]
        for session in sessions where session.phase == .work {
            let key = session.tag?.id.uuidString ?? "untagged"
            var row = rows[key] ?? TagRow(
                tagID: session.tag?.id,
                name: session.tag?.name ?? "Untagged",
                colorHex: session.tag?.colorHex,
                summary: Summary()
            )
            if session.completed { row.summary.sessions += 1 } else { row.summary.skipped += 1 }
            row.summary.focusSeconds += Int(session.durationSeconds.rounded())
            rows[key] = row
        }
        let tagged = rows.values.filter { $0.tagID != nil }.sorted {
            $0.summary.focusSeconds != $1.summary.focusSeconds
                ? $0.summary.focusSeconds > $1.summary.focusSeconds
                : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let untagged = rows["untagged"].map { [$0] } ?? []
        return tagged + untagged
    }
}
