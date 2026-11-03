import AppKit
import SwiftUI

/// Export and the database location.
struct DataSettingsView: View {
    let controller: AppController

    var body: some View {
        Form {
            Section("Export") {
                LabeledContent("All sessions, breaks included") {
                    HStack {
                        ForEach(Exporter.Format.allCases) { format in
                            Button("\(format.rawValue)…") {
                                ExportPanel.run(format: format, store: controller.store)
                            }
                        }
                    }
                }
            }
            Section("Database") {
                LabeledContent("Location") {
                    HStack(spacing: 8) {
                        Text(SessionStore.storeURL.deletingLastPathComponent().path(percentEncoded: false))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([SessionStore.storeURL])
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// The save panel for F10. Writes the chosen format and reports failures.
@MainActor
enum ExportPanel {
    static func run(format: Exporter.Format, store: SessionStore) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .csv ? .commaSeparatedText : .json]
        panel.nameFieldStringValue = Exporter.suggestedFileName(format: format)
        panel.canCreateDirectories = true
        panel.title = "Export Sessions"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Exporter.data(store.allSessions(), format: format)
            try data.write(to: url, options: .atomic)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Export failed"
            alert.runModal()
        }
    }
}
