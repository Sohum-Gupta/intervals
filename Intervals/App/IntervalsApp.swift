import SwiftUI

@main
struct IntervalsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let controller = AppController.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverView(controller: controller)
        } label: {
            MenuBarLabel(engine: controller.engine)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(controller.store.container)

        Settings {
            SettingsView(controller: controller)
        }
        .modelContainer(controller.store.container)
    }
}
