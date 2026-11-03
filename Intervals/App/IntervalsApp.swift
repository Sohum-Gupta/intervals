import SwiftUI

@main
struct IntervalsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var engine: TimerEngine

    init() {
        let engine = TimerEngine()
        engine.transitionHandler = { _ in }
        engine.sessionSink = { _ in }   // Milestone 3 writes these to the store.
        engine.refresh()
        engine.startTicking()
        _engine = State(initialValue: engine)
    }

    var body: some Scene {
        MenuBarExtra {
            MilestoneOnePopover(engine: engine)
        } label: {
            MenuBarLabel(engine: engine)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu bar text: a glyph for the phase plus the countdown (F2 arrives in Milestone 2;
/// this is just enough to see the engine working).
struct MenuBarLabel: View {
    let engine: TimerEngine

    var body: some View {
        let symbol = switch engine.state {
        case .idle: "circle.dotted"
        case .paused: "pause.fill"
        case .running: engine.phase == .work ? "circle.fill" : "circle"
        }
        if case .idle = engine.state {
            Image(systemName: symbol)
        } else {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text(TimeFormat.clock(engine.remaining))
                    .monospacedDigit()
            }
        }
    }
}

/// Temporary popover for trying Milestone 1 by hand. Replaced in Milestone 2.
struct MilestoneOnePopover: View {
    let engine: TimerEngine

    var body: some View {
        VStack(spacing: 12) {
            Text(engine.phase.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(TimeFormat.clock(engine.remaining))
                .font(.system(size: 44, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            HStack(spacing: 8) {
                Button(primaryTitle) { engine.toggle() }
                    .keyboardShortcut(.space, modifiers: [])
                    .buttonStyle(.borderedProminent)
                Button("Skip") { engine.skip() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                    .disabled(engine.state.isIdle)
                Button("Reset") { engine.reset() }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(engine.state.isIdle)
            }
            Text("Cycle \(engine.completedWorkInCycle) of \(engine.settings.sessionsBeforeLongBreak)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Divider()
            Button("Quit Intervals") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 260)
        .animation(.default, value: engine.state)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            engine.refresh()
        }
    }

    private var primaryTitle: String {
        switch engine.state {
        case .idle: "Start"
        case .paused: "Resume"
        case .running: engine.isOvertime ? "Start" : "Pause"
        }
    }
}
