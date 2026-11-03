import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = AppController.shared

        // Re-evaluate immediately after sleep so a deadline that passed is
        // settled at its real end time rather than at the next tick.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { AppController.shared.engine.refresh() }
        }
    }
}
