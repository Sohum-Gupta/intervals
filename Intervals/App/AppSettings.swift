import Foundation
import Observation

/// Bundled alert sounds (F4). Raw values are the UserDefaults representation.
enum AlertSound: String, CaseIterable, Identifiable, Sendable {
    case none
    case systemDefault
    case chime
    case bell
    case softClick
    case marimba

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .systemDefault: "System default"
        case .chime: "Chime"
        case .bell: "Bell"
        case .softClick: "Soft click"
        case .marimba: "Marimba"
        }
    }

    /// Bundled file name, for the four synthesised sounds.
    var fileName: String? {
        switch self {
        case .none, .systemDefault: nil
        case .chime: "Chime"
        case .bell: "Bell"
        case .softClick: "SoftClick"
        case .marimba: "Marimba"
        }
    }
}

/// Every user setting, backed by UserDefaults under the keys named in SPEC.md.
/// The timer portion is pushed to the engine whenever it changes.
@MainActor
@Observable
final class AppSettings {
    enum Key {
        static let alertSound = "alertSound"
        static let alertVolume = "alertVolume"
        static let tickingEnabled = "tickingEnabled"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Called after every timer-settings change so the engine can pick it up.
    @ObservationIgnored var onTimerChange: (@MainActor (TimerSettings) -> Void)?

    var timer: TimerSettings {
        didSet {
            guard timer != oldValue else { return }
            timer.save(to: defaults)
            onTimerChange?(timer)
        }
    }

    var alertSound: AlertSound {
        didSet { defaults.set(alertSound.rawValue, forKey: Key.alertSound) }
    }

    /// 0...1
    var alertVolume: Double {
        didSet { defaults.set(alertVolume, forKey: Key.alertVolume) }
    }

    var tickingEnabled: Bool {
        didSet { defaults.set(tickingEnabled, forKey: Key.tickingEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        timer = TimerSettings.load(from: defaults)
        alertSound = defaults.string(forKey: Key.alertSound).flatMap(AlertSound.init(rawValue:)) ?? .chime
        alertVolume = defaults.object(forKey: Key.alertVolume) as? Double ?? 0.7
        tickingEnabled = defaults.bool(forKey: Key.tickingEnabled)
    }
}
