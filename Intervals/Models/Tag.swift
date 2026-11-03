import Foundation
import SwiftData

/// A user-created label with a colour. Deleting a tag leaves its sessions untagged.
@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    /// Unique, compared case-insensitively.
    var name: String
    var colorHex: String
    var sortOrder: Int
    @Relationship(deleteRule: .nullify, inverse: \Session.tag) var sessions: [Session] = []

    init(id: UUID = UUID(), name: String, colorHex: String, sortOrder: Int) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }
}
