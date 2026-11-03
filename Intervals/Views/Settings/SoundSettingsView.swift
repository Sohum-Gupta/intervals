import SwiftUI

struct SoundSettingsView: View {
    @Bindable var settings: AppSettings
    let sounds: SoundPlayer

    var body: some View {
        Form {
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
    }
}
