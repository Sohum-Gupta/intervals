import Foundation
import OSLog
import UserNotifications

/// Posts a macOS notification at each interval end (F4). Sounds are played by
/// `SoundPlayer`, so notifications themselves are silent.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let log = Logger(subsystem: "com.sohum.intervals", category: "notifications")

    override init() {
        super.init()
        center.delegate = self
    }

    /// First-run prompt. Later calls are no-ops once the user has answered.
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert]) { [log] granted, error in
            if let error {
                log.error("authorization failed: \(error.localizedDescription, privacy: .public)")
            } else {
                log.info("authorization granted: \(granted)")
            }
        }
    }

    func post(for transition: TimerTransition) {
        let content = UNMutableNotificationContent()
        switch transition.reason {
        case .completed:
            content.title = "Focus complete"
            content.body = transition.to == .longBreak ? "Time for a long break." : "Take a short break."
        case .breakEnded:
            content.title = "Break over"
            content.body = "Ready for the next focus session?"
        case .autoStarted:
            content.title = "Focus started"
            content.body = "The next focus session began automatically."
        case .skipped, .started, .newDay:
            return
        }
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: "interval-\(transition.at.timeIntervalSince1970)", content: content, trigger: nil)
        center.add(request) { [log] error in
            if let error { log.error("post failed: \(error.localizedDescription, privacy: .public)") }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
