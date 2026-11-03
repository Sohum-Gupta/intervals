import SwiftUI

@main
struct IntervalsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Text("Intervals")
                .padding()
        } label: {
            Image(systemName: "circle.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
