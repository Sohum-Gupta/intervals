import SwiftUI

enum SettingsTab: String, CaseIterable {
    case timer, sounds, tags
}

/// The standard Settings window (⌘,). Tabs arrive as their milestones do.
struct SettingsView: View {
    @Bindable var controller: AppController

    var body: some View {
        TabView(selection: $controller.settingsTab) {
            Tab("Timer", systemImage: "timer", value: SettingsTab.timer) {
                TimerSettingsView(settings: controller.settings)
            }
            Tab("Sounds", systemImage: "speaker.wave.2", value: SettingsTab.sounds) {
                SoundSettingsView(settings: controller.settings, sounds: controller.sounds)
            }
            Tab("Tags", systemImage: "tag", value: SettingsTab.tags) {
                TagSettingsView(controller: controller)
            }
        }
        .scenePadding()
        .frame(width: 440)
    }
}
