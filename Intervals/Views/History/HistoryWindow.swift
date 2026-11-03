import SwiftData
import SwiftUI

/// Today and History side by side in one window. Stats joins in Milestone 5.
struct HistoryWindow: View {
    let controller: AppController
    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)]) private var tags: [Tag]

    private var history: HistoryState { controller.history }

    var body: some View {
        @Bindable var history = history
        NavigationSplitView {
            List(HistoryState.Section.allCases, selection: $history.section) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 220)
        } detail: {
            switch history.section {
            case .today:
                DayList(controller: controller, dayStart: Calendar.current.startOfDay(for: controller.engine.now))
                    .navigationTitle("Today")
            case .history:
                VStack(spacing: 0) {
                    filterBar
                    Divider()
                    RangeList(
                        controller: controller,
                        start: history.rangeStart,
                        end: history.rangeEnd,
                        tagFilter: history.tagFilter
                    )
                }
                .navigationTitle("History")
            case .stats:
                StatsView(controller: controller)
                    .navigationTitle("Stats")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if history.section == .history {
                    exportMenu
                }
                if history.section != .stats {
                    Toggle(isOn: $history.showBreaks) {
                        Label("Show breaks", systemImage: "cup.and.saucer")
                    }
                    .help("Show breaks")
                    Button {
                        addSession()
                    } label: {
                        Label("Add session", systemImage: "plus")
                    }
                    .keyboardShortcut("n")
                    .help("Add a session by hand (⌘N)")
                }
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .onDisappear { history.commitPendingDeletion() }
    }

    /// Range presets, from/to fields and the tag filter, in one row above the list.
    private var filterBar: some View {
        @Bindable var history = history
        return HStack(spacing: 10) {
            Menu {
                ForEach(HistoryState.RangePreset.allCases) { preset in
                    Button(preset.rawValue) { history.applyPreset(preset) }
                }
            } label: {
                Label("Range", systemImage: "calendar")
            }
            .fixedSize()
            .help("Date range presets")
            DatePicker("From", selection: $history.rangeStart, in: ...history.rangeEnd, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                .help("From")
            Text("–").foregroundStyle(.secondary)
            DatePicker("To", selection: $history.rangeEnd, in: history.rangeStart..., displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                .help("To")
            Spacer()
            tagFilterMenu
                .fixedSize()
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var exportMenu: some View {
        Menu {
            ForEach(Exporter.Format.allCases) { format in
                Button("Export as \(format.rawValue)…") {
                    ExportPanel.run(format: format, store: controller.store)
                }
            }
        } label: {
            Label("Export…", systemImage: "square.and.arrow.up")
        }
        .help("Export all sessions")
    }

    private var tagFilterMenu: some View {
        @Bindable var history = history
        return Picker("Tag", selection: $history.tagFilter) {
            Text("All tags").tag(HistoryState.TagFilter.all)
            Text("Untagged").tag(HistoryState.TagFilter.untagged)
            if !tags.isEmpty {
                Divider()
                ForEach(tags) { tag in
                    Label {
                        Text(tag.name)
                    } icon: {
                        Image(nsImage: TagColor.dot(hex: tag.colorHex))
                    }
                    .tag(HistoryState.TagFilter.tag(tag.id))
                }
            }
        }
        .pickerStyle(.menu)
        .help("Filter by tag")
    }

    private func addSession() {
        let now = controller.engine.now
        let session = controller.store.addManualSession(
            startedAt: now.addingTimeInterval(-25 * 60),
            endedAt: now,
            tag: controller.store.tag(id: controller.engine.currentTagID)
        )
        history.section = .today
        history.newlyAddedID = session.id
        history.editingID = session.id
    }
}

/// Today's sessions, newest first.
private struct DayList: View {
    let controller: AppController
    @Query private var sessions: [Session]

    init(controller: AppController, dayStart: Date) {
        self.controller = controller
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        _sessions = Query(
            filter: #Predicate<Session> { $0.startedAt >= dayStart && $0.startedAt < dayEnd },
            sort: [SortDescriptor(\Session.startedAt, order: .reverse)]
        )
    }

    var body: some View {
        SessionList(controller: controller, sessions: sessions, groupByDay: false)
    }
}

/// Sessions in a date range, grouped by day.
private struct RangeList: View {
    let controller: AppController
    @Query private var sessions: [Session]

    init(controller: AppController, start: Date, end: Date, tagFilter: HistoryState.TagFilter) {
        self.controller = controller
        let rangeStart = Calendar.current.startOfDay(for: start)
        let rangeEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end)) ?? end
        let predicate: Predicate<Session>
        switch tagFilter {
        case .all:
            predicate = #Predicate { $0.startedAt >= rangeStart && $0.startedAt < rangeEnd }
        case .untagged:
            predicate = #Predicate { $0.startedAt >= rangeStart && $0.startedAt < rangeEnd && $0.tag == nil }
        case .tag(let id):
            predicate = #Predicate { $0.startedAt >= rangeStart && $0.startedAt < rangeEnd && $0.tag?.id == id }
        }
        _sessions = Query(filter: predicate, sort: [SortDescriptor(\Session.startedAt, order: .reverse)])
    }

    var body: some View {
        SessionList(controller: controller, sessions: sessions, groupByDay: true)
    }
}
