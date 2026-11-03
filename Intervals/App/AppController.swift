import AppKit
import Observation

/// Owns the engine, settings and side effects for the lifetime of the app.
@MainActor
@Observable
final class AppController {
    static let shared = AppController()

    let settings: AppSettings
    let engine: TimerEngine
    let store: SessionStore
    @ObservationIgnored let sounds = SoundPlayer()
    @ObservationIgnored let notifier = Notifier()

    /// Which Settings tab to show when the window opens next.
    var settingsTab: SettingsTab = .timer

    /// Filters, selection and the pending undo for the History window.
    let history = HistoryState()

    private init() {
        let settings = AppSettings()
        let engine = TimerEngine(settings: settings.timer)
        let store: SessionStore
        do {
            store = SessionStore(container: try SessionStore.makeContainer())
        } catch {
            // The on-disk store is unusable; keep the timer working in memory
            // rather than refusing to launch. The data is still on disk.
            store = SessionStore(container: try! SessionStore.makeContainer(inMemory: true))
        }
        self.settings = settings
        self.engine = engine
        self.store = store
        history.store = store

        settings.onTimerChange = { engine.settings = $0 }
        engine.sessionSink = { store.record($0) }
        engine.transitionHandler = { [weak self] transition in
            self?.handle(transition)
        }
        // Ask for notification permission before the first refresh can post one.
        notifier.requestAuthorization()
        engine.refresh()
        engine.startTicking()
        observeTicking()
        observeAppearance()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    /// Remove a tag everywhere, including from the interval in progress.
    func delete(_ tag: Tag) {
        if engine.currentTagID == tag.id { engine.currentTagID = nil }
        store.delete(tag)
    }

    private func handle(_ transition: TimerTransition) {
        switch transition.reason {
        case .completed, .breakEnded, .autoStarted:
            sounds.play(settings.alertSound, volume: settings.alertVolume)
            notifier.post(for: transition)
        case .skipped, .started, .newDay:
            break
        }
    }

    /// Apply the appearance setting app-wide, now and whenever it changes.
    private func observeAppearance() {
        withObservationTracking {
            NSApplication.shared.appearance = switch settings.appearance {
            case .system: nil
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
        } onChange: {
            Task { @MainActor [weak self] in self?.observeAppearance() }
        }
    }

    /// Keep the tick loop in step with the timer: on during running work when enabled.
    private func observeTicking() {
        withObservationTracking {
            let active = settings.tickingEnabled && engine.state.isRunning && engine.phase == .work
            sounds.setTicking(active, volume: settings.alertVolume)
        } onChange: {
            Task { @MainActor [weak self] in self?.observeTicking() }
        }
    }
}
