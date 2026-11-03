import Foundation

/// The timer-tab settings (F1 plus auto-start). Lives in UserDefaults under the
/// keys named in SPEC.md; the engine holds a copy and the UI pushes changes.
struct TimerSettings: Codable, Equatable, Sendable {
    static let minuteRange = 1...120
    static let cycleRange = 1...10

    var workMinutes: Int = 25 { didSet { workMinutes = workMinutes.clamped(to: Self.minuteRange) } }
    var shortBreakMinutes: Int = 5 { didSet { shortBreakMinutes = shortBreakMinutes.clamped(to: Self.minuteRange) } }
    var longBreakMinutes: Int = 15 { didSet { longBreakMinutes = longBreakMinutes.clamped(to: Self.minuteRange) } }
    var sessionsBeforeLongBreak: Int = 4 { didSet { sessionsBeforeLongBreak = sessionsBeforeLongBreak.clamped(to: Self.cycleRange) } }
    var autoStartNext: Bool = false

    init() {}

    init(work: Int, shortBreak: Int, longBreak: Int, sessionsBeforeLongBreak: Int, autoStartNext: Bool = false) {
        self.workMinutes = work.clamped(to: Self.minuteRange)
        self.shortBreakMinutes = shortBreak.clamped(to: Self.minuteRange)
        self.longBreakMinutes = longBreak.clamped(to: Self.minuteRange)
        self.sessionsBeforeLongBreak = sessionsBeforeLongBreak.clamped(to: Self.cycleRange)
        self.autoStartNext = autoStartNext
    }

    func seconds(for phase: Phase) -> Int {
        switch phase {
        case .work: workMinutes * 60
        case .shortBreak: shortBreakMinutes * 60
        case .longBreak: longBreakMinutes * 60
        }
    }

    func length(of phase: Phase) -> TimeInterval {
        TimeInterval(seconds(for: phase))
    }

    // MARK: UserDefaults

    enum Key {
        static let workMinutes = "workMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let sessionsBeforeLongBreak = "sessionsBeforeLongBreak"
        static let autoStartNext = "autoStartNext"
    }

    static func load(from defaults: UserDefaults = .standard) -> TimerSettings {
        var settings = TimerSettings()
        if let value = defaults.object(forKey: Key.workMinutes) as? Int { settings.workMinutes = value }
        if let value = defaults.object(forKey: Key.shortBreakMinutes) as? Int { settings.shortBreakMinutes = value }
        if let value = defaults.object(forKey: Key.longBreakMinutes) as? Int { settings.longBreakMinutes = value }
        if let value = defaults.object(forKey: Key.sessionsBeforeLongBreak) as? Int { settings.sessionsBeforeLongBreak = value }
        if let value = defaults.object(forKey: Key.autoStartNext) as? Bool { settings.autoStartNext = value }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(workMinutes, forKey: Key.workMinutes)
        defaults.set(shortBreakMinutes, forKey: Key.shortBreakMinutes)
        defaults.set(longBreakMinutes, forKey: Key.longBreakMinutes)
        defaults.set(sessionsBeforeLongBreak, forKey: Key.sessionsBeforeLongBreak)
        defaults.set(autoStartNext, forKey: Key.autoStartNext)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
