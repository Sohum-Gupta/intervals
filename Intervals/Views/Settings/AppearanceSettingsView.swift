import SwiftUI

struct AppearanceSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(Appearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                LabeledContent("Accent") {
                    HStack(spacing: 6) {
                        Circle().fill(Color.accentColor).frame(width: 12, height: 12)
                        Text("Used for focus; breaks are teal.")
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Applies to the popover, History and Settings windows.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
