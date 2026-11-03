import SwiftUI

/// The progress ring. `progress` is the fraction of the interval still to go,
/// so the ring empties as time passes.
struct RingView: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 11

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

/// Colours and names shared by the popover and the menu bar.
enum PhaseStyle {
    static func color(for phase: Phase) -> Color {
        phase == .work ? .accentColor : .teal
    }
}
