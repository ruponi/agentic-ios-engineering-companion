import Foundation
import SwiftData

/// Adds synchronisation metadata and a durable conflict record. Every addition
/// is optional, so a row written under V1 stays meaningful: a nil revision
/// means "never synchronised", not "corrupt".
enum FieldNotesSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] { [StoredNote.self, NoteConflict.self] }

    @Model
    final class StoredNote {
        @Attribute(.unique) var id: UUID
        var title: String
        var body: String
        var createdAt: Date
        var modifiedAt: Date?
        var serverRevision: Int?
        var lastSyncedBody: String?

        init(
            id: UUID,
            title: String,
            body: String,
            createdAt: Date,
            modifiedAt: Date? = nil,
            serverRevision: Int? = nil,
            lastSyncedBody: String? = nil
        ) {
            self.id = id
            self.title = title
            self.body = body
            self.createdAt = createdAt
            self.modifiedAt = modifiedAt
            self.serverRevision = serverRevision
            self.lastSyncedBody = lastSyncedBody
        }
    }

    @Model
    final class NoteConflict {
        @Attribute(.unique) var id: UUID
        var noteID: UUID
        var remoteTitle: String
        var remoteBody: String
        var remoteRevision: Int
        var detectedAt: Date

        init(
            id: UUID = UUID(),
            noteID: UUID,
            remoteTitle: String,
            remoteBody: String,
            remoteRevision: Int,
            detectedAt: Date
        ) {
            self.id = id
            self.noteID = noteID
            self.remoteTitle = remoteTitle
            self.remoteBody = remoteBody
            self.remoteRevision = remoteRevision
            self.detectedAt = detectedAt
        }
    }
}
