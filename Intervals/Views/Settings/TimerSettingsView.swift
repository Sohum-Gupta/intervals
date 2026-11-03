import SwiftUI

struct TimerSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Lengths") {
                MinutesStepper("Focus", value: $settings.timer.workMinutes)
                MinutesStepper("Short break", value: $settings.timer.shortBreakMinutes)
                MinutesStepper("Long break", value: $settings.timer.longBreakMinutes)
            }
            Section {
                Stepper(value: $settings.timer.sessionsBeforeLongBreak, in: TimerSettings.cycleRange) {
                    LabeledContent("Sessions before a long break", value: "\(settings.timer.sessionsBeforeLongBreak)")
                }
                Toggle("Start the next focus session automatically", isOn: $settings.timer.autoStartNext)
            } footer: {
                Text("Breaks always start on their own when focus ends. Changes apply from the next interval.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// A stepper for a minute count in the spec's 1–120 range, showing "25 min".
struct MinutesStepper: View {
    let title: String
    @Binding var value: Int

    init(_ title: String, value: Binding<Int>) {
        self.title = title
        _value = value
    }

    var body: some View {
        Stepper(value: $value, in: TimerSettings.minuteRange) {
            LabeledContent(title, value: "\(value) min")
        }
    }
}
