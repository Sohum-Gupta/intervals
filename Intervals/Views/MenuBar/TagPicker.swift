import SwiftData
import SwiftUI

/// The tag menu beside the title field: a colour dot and the tag's name.
struct TagPicker: View {
    let controller: AppController
    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)]) private var tags: [Tag]
    @Environment(\.openSettings) private var openSettings

    private var engine: TimerEngine { controller.engine }
    private var current: Tag? { tags.first { $0.id == engine.currentTagID } }

    var body: some View {
        Menu {
            Button {
                engine.currentTagID = nil
            } label: {
                if engine.currentTagID == nil {
                    Label("No tag", systemImage: "checkmark")
                } else {
                    Text("No tag")
                }
            }
            if !tags.isEmpty {
                Divider()
                ForEach(tags) { tag in
                    Button {
                        engine.currentTagID = tag.id
                    } label: {
                        Label {
                            Text(tag.name)
                        } icon: {
                            Image(nsImage: TagColor.dot(hex: tag.colorHex, ring: tag.id == engine.currentTagID))
                        }
                    }
                }
            }
            Divider()
            Button("Manage Tags…") {
                controller.settingsTab = .tags
                NSApp.activate()
                openSettings()
            }
        } label: {
            HStack(spacing: 6) {
                if let current {
                    Image(nsImage: TagColor.dot(hex: current.colorHex, diameter: 8))
                } else {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.quaternary)
                }
                Text(current?.name ?? "Tag")
                    .lineLimit(1)
                    .foregroundStyle(current == nil ? .secondary : .primary)
            }
            .font(.callout)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help("Tag")
        .accessibilityLabel("Tag, \(current?.name ?? "none")")
    }
}
