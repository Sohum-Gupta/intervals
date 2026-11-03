import AppKit
import Observation

/// Owns the engine, settings and side effects for the lifetime of the app.
@MainActor
@Observable
final class AppController {
    static let shared = AppController()

    let settings: AppSettings
    let engine: TimerEngine
    @ObservationIgnored let sounds = SoundPlayer()
    @ObservationIgnored let notifier = Notifier()

    private init() {
        let settings = AppSettings()
        let engine = TimerEngine(settings: settings.timer)
        self.settings = settings
        self.engine = engine

        settings.onTimerChange = { engine.settings = $0 }
        engine.sessionSink = { _ in }   // Milestone 3 writes these to the store.
        engine.transitionHandler = { [weak self] transition in
            self?.handle(transition)
        }
        engine.refresh()
        engine.startTicking()
        observeTicking()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
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
