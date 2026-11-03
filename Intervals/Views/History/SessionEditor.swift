import SwiftData
import SwiftUI

/// The row in edit mode: start, end, title and tag, with Done and Cancel.
struct SessionEditor: View {
    let session: Session
    let controller: AppController
    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)]) private var tags: [Tag]
    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var title: String
    @State private var tagID: UUID?
    @FocusState private var titleFocused: Bool

    init(session: Session, controller: AppController) {
        self.session = session
        self.controller = controller
        _startedAt = State(initialValue: session.startedAt)
        _endedAt = State(initialValue: session.endedAt)
        _title = State(initialValue: session.title)
        _tagID = State(initialValue: session.tag?.id)
    }

    private var isValid: Bool { endedAt > startedAt }
    private var isNew: Bool { controller.history.newlyAddedID == session.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                DatePicker("Start", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.field)
                Text("–").foregroundStyle(.secondary)
                DatePicker("End", selection: $endedAt, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.field)
                Text(isValid ? TimeFormat.duration(Int(endedAt.timeIntervalSince(startedAt))) : "End must be after start")
                    .font(.caption)
                    .foregroundStyle(isValid ? .secondary : Color.red)
                    .monospacedDigit()
                Spacer()
            }
            HStack(spacing: 8) {
                if session.phase == .work {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFocused)
                        .onSubmit(done)
                    Picker("Tag", selection: $tagID) {
                        Text("No tag").tag(UUID?.none)
                        ForEach(tags) { tag in
                            Label {
                                Text(tag.name)
                            } icon: {
                                Image(nsImage: TagColor.dot(hex: tag.colorHex))
                            }
                            .tag(UUID?.some(tag.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                } else {
                    Text(session.phase.displayName)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
        }
        .padding(.vertical, 6)
        .onAppear { if session.phase == .work { titleFocused = true } }
    }

    private func done() {
        guard isValid else { return }
        controller.store.update(
            session,
            startedAt: startedAt,
            endedAt: endedAt,
            title: title,
            tag: tags.first { $0.id == tagID }
        )
        controller.history.newlyAddedID = nil
        controller.history.editingID = nil
    }

    private func cancel() {
        if isNew {
            controller.store.delete(session)
        }
        controller.history.newlyAddedID = nil
        controller.history.editingID = nil
    }
}
