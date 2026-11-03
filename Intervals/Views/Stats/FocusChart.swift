import Charts
import SwiftUI

/// Focus minutes per day for the last 14 days. One series, so no legend;
/// hovering a bar shows the day and its total.
struct FocusChart: View {
    let days: [Stats.Day]
    @State private var hovered: Date?

    private var maxMinutes: Double { max(days.map(\.focusMinutes).max() ?? 0, 30) }

    /// Grid lines at a round number of minutes, three or four of them.
    private var tickMinutes: [Double] {
        let step = [15.0, 30, 60, 120, 180, 240].first { maxMinutes / $0 <= 4 } ?? 240
        return stride(from: 0, through: (maxMinutes / step).rounded(.up) * step, by: step).map { $0 }
    }

    private func tickLabel(_ minutes: Double) -> String {
        let total = Int(minutes)
        let hours = total / 60, mins = total % 60
        if hours > 0 { return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Day", day.day, unit: .day),
                y: .value("Focus", day.focusMinutes),
                width: .ratio(0.55)
            )
            .foregroundStyle(hovered == nil || hovered == day.day ? Color.accentColor : Color.accentColor.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .accessibilityLabel(day.day.formatted(.dateTime.weekday(.wide).day().month()))
            .accessibilityValue(TimeFormat.duration(day.focusSeconds))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .foregroundStyle(Calendar.current.isDateInToday(date) ? .primary : .secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: tickMinutes) { value in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text(tickLabel(minutes))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...(tickMinutes.last ?? maxMinutes))
        .chartXSelection(value: $hovered)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let hovered, let day = days.first(where: { Calendar.current.isDate($0.day, inSameDayAs: hovered) }),
                   let x = proxy.position(forX: day.day) {
                    let plot = geometry[proxy.plotFrame!]
                    tooltip(for: day)
                        .position(x: (plot.minX + x).clamped(to: (plot.minX + 50)...(plot.maxX - 50)), y: plot.minY + 14)
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: hovered)
    }

    private func tooltip(for day: Stats.Day) -> some View {
        HStack(spacing: 6) {
            Text(day.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .foregroundStyle(.secondary)
            Text(TimeFormat.duration(day.focusSeconds))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.quaternary))
        .fixedSize()
    }
}
