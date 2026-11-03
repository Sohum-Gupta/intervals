import SwiftUI

/// The standard Settings window (⌘,). Tabs arrive as their milestones do.
struct SettingsView: View {
    let controller: AppController

    var body: some View {
        TabView {
            Tab("Timer", systemImage: "timer") {
                TimerSettingsView(settings: controller.settings)
            }
            Tab("Sounds", systemImage: "speaker.wave.2") {
                SoundSettingsView(settings: controller.settings, sounds: controller.sounds)
            }
        }
        .scenePadding()
        .frame(width: 440)
    }
}
