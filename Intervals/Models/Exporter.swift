import Foundation

/// CSV and JSON export of every session (F10). Both carry the same columns;
/// JSON adds the tag's colour so the tag list could be rebuilt later.
enum Exporter {
    static let columns = [
        "id", "phase", "started_at", "ended_at", "planned_seconds", "paused_seconds",
        "duration_seconds", "completed", "title", "tag", "is_manual",
    ]

    /// ISO 8601 with the local offset, e.g. `2026-11-02T09:00:00-08:00`.
    static func timestamp(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func csv(_ sessions: [Session], timeZone: TimeZone = .current) -> String {
        var lines = [columns.joined(separator: ",")]
        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            let fields: [String] = [
                session.id.uuidString,
                session.phase.rawValue,
                timestamp(session.startedAt, timeZone: timeZone),
                timestamp(session.endedAt, timeZone: timeZone),
                String(session.plannedSeconds),
                String(session.pausedSeconds),
                String(Int(session.durationSeconds.rounded())),
                session.completed ? "true" : "false",
                session.title,
                session.tag?.name ?? "",
                session.isManual ? "true" : "false",
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Quote a field when it holds a comma, quote, or line break; double any quotes inside.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func json(_ sessions: [Session], timeZone: TimeZone = .current) throws -> Data {
        let rows: [[String: Any]] = sessions.sorted(by: { $0.startedAt < $1.startedAt }).map { session in
            [
                "id": session.id.uuidString,
                "phase": session.phase.rawValue,
                "started_at": timestamp(session.startedAt, timeZone: timeZone),
                "ended_at": timestamp(session.endedAt, timeZone: timeZone),
                "planned_seconds": session.plannedSeconds,
                "paused_seconds": session.pausedSeconds,
                "duration_seconds": Int(session.durationSeconds.rounded()),
                "completed": session.completed,
                "title": session.title,
                "tag": session.tag?.name as Any? ?? NSNull(),
                "tag_color": session.tag?.colorHex as Any? ?? NSNull(),
                "is_manual": session.isManual,
            ]
        }
        return try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
    }

    enum Format: String, CaseIterable, Identifiable {
        case csv = "CSV", json = "JSON"
        var id: String { rawValue }
        var fileExtension: String { rawValue.lowercased() }
    }

    static func data(_ sessions: [Session], format: Format) throws -> Data {
        switch format {
        case .csv: Data(csv(sessions).utf8)
        case .json: try json(sessions)
        }
    }

    static func suggestedFileName(format: Format, date: Date = Date(), timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return "Intervals \(formatter.string(from: date)).\(format.fileExtension)"
    }
}
