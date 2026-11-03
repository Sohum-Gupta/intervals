import Foundation
import Observation

/// What the History window shows and the one deletion waiting on its undo toast.
@MainActor
@Observable
final class HistoryState {
    enum Section: String, CaseIterable, Identifiable {
        case today, history, stats
        var id: String { rawValue }
        var title: String {
            switch self {
            case .today: "Today"
            case .history: "History"
            case .stats: "Stats"
            }
        }
        var symbol: String {
            switch self {
            case .today: "sun.max"
            case .history: "calendar"
            case .stats: "chart.bar"
            }
        }
    }

    enum TagFilter: Hashable {
        case all, untagged, tag(UUID)
    }

    enum RangePreset: String, CaseIterable, Identifiable {
        case week = "Last 7 days", month = "Last 30 days", quarter = "Last 90 days", all = "All time"
        var id: String { rawValue }
    }

    var section: Section = .today
    var showBreaks = false
    var tagFilter: TagFilter = .all
    var rangeStart: Date = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    var rangeEnd: Date = Date()
    var editingID: UUID?
    /// A session just added by hand; cancelling its first edit removes it.
    var newlyAddedID: UUID?

    @ObservationIgnored var store: SessionStore?

    // MARK: Undo toast

    private(set) var pendingDeletion: Session?
    @ObservationIgnored private var deletionTask: Task<Void, Never>?

    static let undoWindow: Duration = .seconds(6)

    /// Hide the session now; delete it for real once the toast expires.
    func delete(_ session: Session) {
        commitPendingDeletion()
        pendingDeletion = session
        if editingID == session.id { editingID = nil }
        deletionTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled else { return }
            self?.commitPendingDeletion()
        }
    }

    func undoDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
        pendingDeletion = nil
    }

    func commitPendingDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
        guard let session = pendingDeletion else { return }
        pendingDeletion = nil
        store?.delete(session)
    }

    func applyPreset(_ preset: RangePreset, now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        rangeEnd = now
        switch preset {
        case .week: rangeStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .month: rangeStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        case .quarter: rangeStart = calendar.date(byAdding: .day, value: -89, to: today) ?? today
        case .all: rangeStart = Date(timeIntervalSince1970: 0)
        }
    }
}
