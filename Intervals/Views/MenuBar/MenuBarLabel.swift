import AppKit
import SwiftUI

/// The status item: a glyph for the phase and the countdown as monospaced digits.
/// `● 24:59` during work (tinted with the accent colour), `○ 04:30` on a break,
/// `○ +03:12` once a break runs over, `‖ 12:10` paused, and just the glyph when idle.
struct MenuBarLabel: View {
    let engine: TimerEngine

    var body: some View {
        HStack(spacing: 5) {
            Image(nsImage: glyph)
            if !engine.state.isIdle {
                Text(TimeFormat.clock(engine.remaining))
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var glyph: NSImage {
        let name: String
        var tint: NSColor?
        switch engine.state {
        case .idle:
            name = "circle.dotted"
        case .paused:
            name = "pause.fill"
        case .running(let phase, _, _):
            name = phase == .work ? "circle.fill" : "circle"
            if phase == .work { tint = NSColor(named: "AccentColor") }
        }
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        if let tint {
            let image = base.withSymbolConfiguration(config.applying(.init(paletteColors: [tint])))!
            image.isTemplate = false
            return image
        }
        let image = base.withSymbolConfiguration(config)!
        image.isTemplate = true
        return image
    }

    private var accessibilityText: String {
        switch engine.state {
        case .idle: "Intervals, idle"
        case .paused: "Intervals, paused, \(TimeFormat.clock(engine.remaining)) left"
        case .running:
            engine.isOvertime
                ? "Intervals, break over by \(TimeFormat.clock(engine.remaining))"
                : "Intervals, \(engine.phase.displayName), \(TimeFormat.clock(engine.remaining)) left"
        }
    }
}
