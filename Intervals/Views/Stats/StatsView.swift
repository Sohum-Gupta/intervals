import SwiftData
import SwiftUI

/// Three summary tiles, the 14-day chart, and a per-tag table for the
/// selected tile's range.
struct StatsView: View {
    let controller: AppController
    @State private var selectedRange: Stats.Range = .today

    private var store: SessionStore { controller.store }
    private var now: Date { controller.engine.now }

    var body: some View {
        // Reading changeCount here re-evaluates the body after every write.
        let _ = store.changeCount
        let calendar = Calendar.current
        let chartEnd = calendar.startOfDay(for: now)
        let chartStart = calendar.date(byAdding: .day, value: -13, to: chartEnd) ?? chartEnd
        let chartSessions = store.workSessions(from: chartStart, to: calendar.date(byAdding: .day, value: 1, to: chartEnd) ?? now)
        let interval = selectedRange.interval(containing: now, calendar: calendar)
        let rangeSessions = store.workSessions(from: interval.start, to: interval.end)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                tiles(calendar: calendar)
                section("Last 14 days") {
                    FocusChart(days: Stats.daily(chartSessions, days: 14, endingOn: now, calendar: calendar))
                        .frame(height: 180)
                }
                section("By tag · \(selectedRange.rawValue)") {
                    TagTable(rows: Stats.perTag(rangeSessions))
                }
            }
            .padding(24)
        }
        .background(.background)
    }

    private func tiles(calendar: Calendar) -> some View {
        HStack(spacing: 12) {
            ForEach(Stats.Range.allCases) { range in
                let interval = range.interval(containing: now, calendar: calendar)
                let summary = Stats.summary(of: store.workSessions(from: interval.start, to: interval.end))
                StatTile(title: range.rawValue, summary: summary, selected: range == selectedRange) {
                    withAnimation(.snappy(duration: 0.2)) { selectedRange = range }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

/// One of Today / This week / This month. Click to drive the per-tag table.
private struct StatTile: View {
    let title: String
    let summary: Stats.Summary
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                Text(TimeFormat.duration(summary.focusSeconds))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(summary.sessions == 1 ? "1 session" : "\(summary.sessions) sessions")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.quaternary.opacity(selected ? 0.7 : 0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(TimeFormat.summary(sessions: summary.sessions, focusSeconds: summary.focusSeconds))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Sessions, skipped and focus time per tag, with the tag's colour dot.
private struct TagTable: View {
    let rows: [Stats.TagRow]

    var body: some View {
        if rows.isEmpty {
            Text("No focus sessions in this range.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Table(rows) {
                TableColumn("Tag") { row in
                    HStack(spacing: 8) {
                        if let hex = row.colorHex {
                            Image(nsImage: TagColor.dot(hex: hex, diameter: 9))
                        } else {
                            Image(systemName: "circle.dotted")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        Text(row.name)
                            .foregroundStyle(row.tagID == nil ? .secondary : .primary)
                    }
                }
                TableColumn("Sessions") { row in
                    Text("\(row.summary.sessions)").monospacedDigit()
                }
                .width(80)
                TableColumn("Skipped") { row in
                    Text("\(row.summary.skipped)").monospacedDigit().foregroundStyle(.secondary)
                }
                .width(80)
                TableColumn("Focus") { row in
                    Text(TimeFormat.duration(row.summary.focusSeconds)).monospacedDigit()
                }
                .width(90)
            }
            .frame(height: CGFloat(rows.count) * 28 + 36)
            .scrollDisabled(true)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
