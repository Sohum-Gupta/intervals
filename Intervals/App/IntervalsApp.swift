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

        Window("History", id: "history") {
            HistoryWindow(controller: controller)
        }
        .defaultSize(width: 760, height: 520)
        .modelContainer(controller.store.container)

        Settings {
            SettingsView(controller: controller)
        }
        .modelContainer(controller.store.container)
    }
}
