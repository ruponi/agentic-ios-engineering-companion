import Foundation
import SwiftData

/// Adds disposable, source-attributed personal context without changing the
/// frozen V1 or V2 declarations.
enum FieldNotesSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [StoredNote.self, NoteConflict.self, PersonalContextRecord.self]
    }

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

    @Model
    final class PersonalContextRecord {
        @Attribute(.unique) var id: UUID
        var value: String
        var sourceNoteID: UUID
        var derivedAt: Date
        var derivationVersion: String
        var expiresAt: Date

        init(
            id: UUID,
            value: String,
            sourceNoteID: UUID,
            derivedAt: Date,
            derivationVersion: String,
            expiresAt: Date
        ) {
            self.id = id
            self.value = value
            self.sourceNoteID = sourceNoteID
            self.derivedAt = derivedAt
            self.derivationVersion = derivationVersion
            self.expiresAt = expiresAt
        }
    }
}

typealias StoredNote = FieldNotesSchemaV3.StoredNote
typealias StoredNoteConflict = FieldNotesSchemaV3.NoteConflict
typealias StoredPersonalContext = FieldNotesSchemaV3.PersonalContextRecord
