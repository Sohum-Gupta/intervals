import SwiftData
import SwiftUI

/// The list shared by Today and History: rows, day sections, inline editing,
/// ⌫ and swipe to delete, and the undo toast.
struct SessionList: View {
    let controller: AppController
    let sessions: [Session]
    let groupByDay: Bool
    @State private var selection: UUID?

    private var history: HistoryState { controller.history }
    private var store: SessionStore { controller.store }

    private var visible: [Session] {
        sessions.filter { session in
            session.id != history.pendingDeletion?.id && (history.showBreaks || session.phase == .work)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if visible.isEmpty {
                emptyState
            } else {
                list
            }
            if let pending = history.pendingDeletion {
                UndoToast(message: pending.phase == .work ? "Session deleted" : "Break deleted") {
                    history.undoDeletion()
                }
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: history.pendingDeletion?.id)
        .animation(.snappy(duration: 0.2), value: history.editingID)
    }

    private var list: some View {
        List(selection: $selection) {
            if groupByDay {
                ForEach(days, id: \.day) { group in
                    Section {
                        rows(group.sessions)
                    } header: {
                        DayHeader(day: group.day, sessions: group.sessions)
                    }
                }
            } else {
                rows(visible)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .onDeleteCommand(perform: deleteSelected)
    }

    @ViewBuilder
    private func rows(_ sessions: [Session]) -> some View {
        ForEach(sessions) { session in
            Group {
                if history.editingID == session.id {
                    SessionEditor(session: session, controller: controller)
                } else {
                    SessionRow(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { beginEditing(session) }
                        .contextMenu {
                            Button("Edit") { beginEditing(session) }
                            Divider()
                            Button("Delete", role: .destructive) { history.delete(session) }
                        }
                }
            }
            .tag(session.id)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    history.delete(session)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var days: [(day: Date, sessions: [Session])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visible) { calendar.startOfDay(for: $0.startedAt) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: groupByDay ? "calendar.badge.clock" : "sun.max")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(groupByDay ? "No sessions in this range" : "Nothing recorded yet today")
                .font(.title3.weight(.medium))
            Text(groupByDay
                 ? "Widen the range or change the tag filter."
                 : "Start a focus session from the menu bar, or add one by hand.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func beginEditing(_ session: Session) {
        history.newlyAddedID = nil
        history.editingID = session.id
        selection = session.id
    }

    private func deleteSelected() {
        guard let selection, let session = visible.first(where: { $0.id == selection }) else { return }
        history.delete(session)
        self.selection = nil
    }
}

/// "Today", "Yesterday" or a full date, plus the day's focus total.
private struct DayHeader: View {
    let day: Date
    let sessions: [Session]

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(total)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var total: String {
        let work = sessions.filter { $0.phase == .work }
        let seconds = Int(work.reduce(0.0) { $0 + $1.durationSeconds })
        return TimeFormat.summary(sessions: work.filter(\.completed).count, focusSeconds: seconds)
    }
}

/// One session: time range, duration, title, tag chip.
struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Text(timeRange)
                .monospacedDigit()
                .foregroundStyle(session.phase.isBreak ? .tertiary : .secondary)
                .frame(width: 128, alignment: .leading)
            Text(TimeFormat.duration(Int(session.durationSeconds)))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
                .foregroundStyle(session.phase.isBreak ? .tertiary : .primary)
            titleView
            Spacer(minLength: 8)
            if session.phase == .work, !session.completed {
                Text("Skipped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            if session.isManual {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("Added or edited by hand")
            }
            if let tag = session.tag {
                TagChip(tag: tag)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var titleView: some View {
        if session.phase.isBreak {
            Text(session.phase.displayName)
                .foregroundStyle(.tertiary)
        } else if session.title.isEmpty {
            Text("Untitled")
                .foregroundStyle(.tertiary)
        } else {
            Text(session.title)
                .lineLimit(1)
        }
    }

    private var timeRange: String {
        let start = session.startedAt.formatted(date: .omitted, time: .shortened)
        let end = session.endedAt.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}

struct TagChip: View {
    let tag: Tag

    var body: some View {
        HStack(spacing: 5) {
            Image(nsImage: TagColor.dot(hex: tag.colorHex, diameter: 7))
            Text(tag.name)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(hex: tag.colorHex).opacity(0.14), in: Capsule())
    }
}

/// "Session deleted  Undo", shown for a few seconds after a delete.
private struct UndoToast: View {
    let message: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(message)
            Button("Undo", action: undo)
                .keyboardShortcut("z")
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}
