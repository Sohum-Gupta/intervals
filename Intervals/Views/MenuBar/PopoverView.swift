import SwiftUI

/// The card under the menu bar item: ring, session dots, title, controls, footer.
struct PopoverView: View {
    let controller: AppController
    @Environment(\.openSettings) private var openSettings
    @FocusState private var titleFocused: Bool

    private var engine: TimerEngine { controller.engine }

    var body: some View {
        VStack(spacing: 18) {
            ring
            sessionDots
            titleField
            controls
            Divider()
            footer
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .frame(width: 300)
        .background(.regularMaterial)
        .animation(.easeInOut(duration: 0.45), value: engine.phase)
        .animation(.snappy(duration: 0.25), value: engine.state)
    }

    // MARK: Ring

    private var ring: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !engine.state.isRunning)) { context in
            ZStack {
                RingView(progress: engine.progress(at: context.date), color: PhaseStyle.color(for: engine.phase))
                VStack(spacing: 2) {
                    Text(phaseLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                    Text(TimeFormat.clock(engine.remaining(at: context.date)))
                        .font(.system(size: 42, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .foregroundStyle(engine.state.isPaused ? .secondary : .primary)
                }
            }
        }
        .frame(width: 190, height: 190)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(phaseLabel), \(TimeFormat.clock(engine.remaining))")
    }

    private var phaseLabel: String {
        if engine.isOvertime { return "Break over" }
        if engine.state.isPaused { return "Paused" }
        return engine.phase.displayName
    }

    // MARK: Session dots

    private var sessionDots: some View {
        let total = engine.settings.sessionsBeforeLongBreak
        let done = engine.phase == .longBreak && !engine.state.isIdle ? total : engine.completedWorkInCycle
        let active = engine.phase == .work && !engine.state.isIdle ? done : -1
        return HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < done ? Color.accentColor : Color.secondary.opacity(0.25))
                    .overlay {
                        if index == active {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) sessions before the long break")
    }

    // MARK: Title

    private var titleField: some View {
        TextField("What are you working on?", text: Binding(
            get: { engine.currentTitle },
            set: { engine.currentTitle = $0 }
        ))
        .textFieldStyle(.plain)
        .font(.body)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .focused($titleFocused)
        .onSubmit { titleFocused = false }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 10) {
            Button(action: engine.toggle) {
                Text(primaryTitle)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.interpolate)
            }
            .keyboardShortcut(titleFocused ? nil : KeyboardShortcut(.space, modifiers: []))
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel(primaryTitle)

            Button(action: engine.skip) {
                Image(systemName: "forward.end.fill")
                    .frame(width: 20)
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(engine.state.isIdle)
            .help("Skip (⌘→)")
            .accessibilityLabel("Skip")

            Button(action: engine.reset) {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 20)
            }
            .keyboardShortcut(".", modifiers: .command)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(engine.state.isIdle)
            .help("Reset (⌘.)")
            .accessibilityLabel("Reset")
        }
    }

    private var primaryTitle: String {
        switch engine.state {
        case .idle: "Start"
        case .paused: "Resume"
        case .running: engine.isOvertime ? "Start" : "Pause"
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text("Intervals")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("Settings…") { showSettings() }
                    .keyboardShortcut(",")
                Divider()
                Button("Quit Intervals") { controller.quit() }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
            } primaryAction: {
                showSettings()
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Settings (⌘,)")
            .accessibilityLabel("Settings")
        }
    }

    private func showSettings() {
        NSApp.activate()
        openSettings()
    }
}
