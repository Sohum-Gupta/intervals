import SwiftUI

struct SoundSettingsView: View {
    @Bindable var settings: AppSettings
    let sounds: SoundPlayer
    var notifier: Notifier?
    @State private var notificationsAllowed = true

    var body: some View {
        Form {
            if !notificationsAllowed {
                Section {
                    LabeledContent {
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notifications are off")
                                Text("Intervals will play the sound but macOS won't show a banner when an interval ends.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "bell.slash")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            Section("Alert") {
                Picker("Sound", selection: $settings.alertSound) {
                    ForEach(AlertSound.allCases) { sound in
                        Text(sound.displayName).tag(sound)
                    }
                }
                .onChange(of: settings.alertSound) { _, sound in
                    sounds.play(sound, volume: settings.alertVolume)
                }
                LabeledContent("Volume") {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.alertVolume, in: 0...1) { editing in
                            if !editing { sounds.play(settings.alertSound, volume: settings.alertVolume) }
                        }
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 200)
                }
                .disabled(settings.alertSound == .none)
            }
            Section {
                Toggle("Tick softly during focus", isOn: $settings.tickingEnabled)
            } footer: {
                Text("The tick uses the alert volume.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshStatus() }
        }
    }

    private func refreshStatus() async {
        guard let notifier else { return }
        let status = await notifier.authorizationStatus()
        notificationsAllowed = status == .authorized || status == .provisional
    }
}
