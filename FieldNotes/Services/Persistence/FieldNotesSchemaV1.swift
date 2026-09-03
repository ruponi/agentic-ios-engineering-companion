import Foundation
import SwiftData

/// The original stored shape. Frozen: this declaration records history and
/// must not be edited to match today's model.
enum FieldNotesSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] { [StoredNote.self] }

    @Model
    final class StoredNote {
        @Attribute(.unique) var id: UUID
        var title: String
        var body: String
        var createdAt: Date

        init(id: UUID, title: String, body: String, createdAt: Date) {
            self.id = id
            self.title = title
            self.body = body
            self.createdAt = createdAt
        }
    }
}
