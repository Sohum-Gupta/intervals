import SwiftData
import SwiftUI

/// Add, rename, recolour and delete tags.
struct TagSettingsView: View {
    let controller: AppController
    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)]) private var tags: [Tag]
    @State private var selection: UUID?
    @State private var newlyAdded: UUID?

    private var store: SessionStore { controller.store }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if tags.isEmpty {
                emptyState
            } else {
                List(selection: $selection) {
                    ForEach(tags) { tag in
                        TagRow(tag: tag, store: store, autoFocus: tag.id == newlyAdded)
                            .tag(tag.id)
                    }
                }
                .listStyle(.bordered)
                .frame(minHeight: 220)
            }
            HStack(spacing: 6) {
                Button(action: addTag) { Image(systemName: "plus").frame(width: 14) }
                    .help("Add tag")
                    .accessibilityLabel("Add tag")
                Button(action: deleteSelected) { Image(systemName: "minus").frame(width: 14) }
                    .disabled(selection == nil)
                    .help("Delete selected tag")
                    .accessibilityLabel("Delete tag")
                    .keyboardShortcut(.delete, modifiers: [])
                Spacer()
                Text("Deleting a tag keeps its sessions, untagged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tag")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No tags yet")
                .font(.headline)
            Text("Tags label your focus sessions so stats can break them down.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func addTag() {
        var name = "New tag"
        var n = 2
        while !store.isNameAvailable(name) { name = "New tag \(n)"; n += 1 }
        if let tag = store.addTag(name: name) {
            selection = tag.id
            newlyAdded = tag.id
        }
    }

    private func deleteSelected() {
        guard let selection, let tag = tags.first(where: { $0.id == selection }) else { return }
        controller.delete(tag)
        self.selection = nil
    }
}

private struct TagRow: View {
    @Bindable var tag: Tag
    let store: SessionStore
    let autoFocus: Bool
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(TagColor.palette, id: \.hex) { swatch in
                    Button {
                        store.recolor(tag, to: swatch.hex)
                    } label: {
                        Label {
                            Text(swatch.name)
                        } icon: {
                            Image(nsImage: TagColor.dot(hex: swatch.hex, ring: swatch.hex.caseInsensitiveCompare(tag.colorHex) == .orderedSame))
                        }
                    }
                }
            } label: {
                Image(nsImage: TagColor.dot(hex: tag.colorHex, diameter: 12))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Colour: \(TagColor.name(for: tag.colorHex))")
            .accessibilityLabel("Colour, \(TagColor.name(for: tag.colorHex))")

            TextField("Name", text: $draft)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }

            Spacer()
            Text(sessionCount)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .onAppear {
            draft = tag.name
            if autoFocus { focused = true }
        }
    }

    private var sessionCount: String {
        let n = tag.sessions.filter { $0.phase == .work }.count
        return n == 0 ? "" : "\(n)"
    }

    private func commit() {
        if !store.rename(tag, to: draft) { draft = tag.name }
        draft = tag.name
    }
}
