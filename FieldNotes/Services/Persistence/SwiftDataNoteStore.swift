import Foundation
import SwiftData

/// The production store. One model actor owns the context and the rebuildable
/// search index, because both change when notes change.
@ModelActor
actor SwiftDataNoteStore: NoteStore {
    private var searchIndex = NoteSearchIndex()
    private var indexIsReady = false

    // MARK: - CaptureService

    func save(_ draft: CaptureDraft) throws {
        let body = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }

        let now = Date()
        modelContext.insert(
            StoredNote(id: UUID(), title: Self.title(from: body), body: body, createdAt: now, modifiedAt: now)
        )
        // Commit durably first; only then invalidate the derived index.
        try modelContext.save()
        indexIsReady = false
    }

    // MARK: - NoteStore

    func notes() throws -> [NoteSummary] {
        try summaries(matching: "")
    }

    func summaries(matching query: String) throws -> [NoteSummary] {
        let notes = try modelContext.fetch(FetchDescriptor<StoredNote>())

        if !indexIsReady {
            searchIndex.rebuild(from: notes.map(Self.document))
            indexIsReady = true
        }

        let notesByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        return searchIndex.rankedIDs(for: query).compactMap { notesByID[$0].map(Self.summary) }
    }

    /// A remote change enters here, never directly into screen state. Two
    /// independent edits preserve the local note and record the remote one;
    /// last-write-wins would silently choose for the user.
    func merge(_ remote: RemoteNote) throws -> MergeOutcome {
        let notes = try modelContext.fetch(FetchDescriptor<StoredNote>())

        guard let local = notes.first(where: { $0.id == remote.id }) else {
            modelContext.insert(
                StoredNote(
                    id: remote.id,
                    title: remote.title,
                    body: remote.body,
                    createdAt: remote.modifiedAt,
                    modifiedAt: remote.modifiedAt,
                    serverRevision: remote.revision,
                    lastSyncedBody: remote.body
                )
            )
            try modelContext.save()
            indexIsReady = false
            return .inserted
        }

        guard remote.revision > (local.serverRevision ?? -1) else { return .unchanged }

        let localChanged = local.lastSyncedBody.map { $0 != local.body } ?? true
        if localChanged {
            modelContext.insert(
                StoredNoteConflict(
                    noteID: local.id,
                    remoteTitle: remote.title,
                    remoteBody: remote.body,
                    remoteRevision: remote.revision,
                    detectedAt: Date()
                )
            )
            try modelContext.save()
            return .conflict
        }

        local.title = remote.title
        local.body = remote.body
        local.modifiedAt = remote.modifiedAt
        local.serverRevision = remote.revision
        local.lastSyncedBody = remote.body
        try modelContext.save()
        indexIsReady = false
        return .updated
    }

    /// Note deletion and derived-memory deletion commit in one model context.
    func deleteNote(id: UUID) throws {
        let notes = try modelContext.fetch(FetchDescriptor<StoredNote>())
        let memories = try modelContext.fetch(FetchDescriptor<StoredPersonalContext>())
        for note in notes where note.id == id { modelContext.delete(note) }
        for memory in memories where memory.sourceNoteID == id { modelContext.delete(memory) }
        try modelContext.save()
        indexIsReady = false
    }

    // MARK: - Crossing points

    private static func title(from body: String) -> String {
        let firstLine = body.split(whereSeparator: \.isNewline).first
        return String(firstLine?.prefix(60) ?? "Field Note")
    }

    private static func document(_ note: StoredNote) -> SearchDocument {
        SearchDocument(
            id: note.id,
            title: note.title,
            body: note.body,
            modifiedAt: note.modifiedAt ?? note.createdAt
        )
    }

    private static func summary(_ note: StoredNote) -> NoteSummary {
        NoteSummary(
            id: note.id,
            title: note.title,
            excerpt: String(note.body.prefix(160)),
            modifiedAt: note.modifiedAt ?? note.createdAt
        )
    }
}

/// Composition helper. Migration failure is reported, never reinterpreted as
/// permission to create an empty replacement database.
enum FieldNotesPersistence {
    static func liveContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: FieldNotesSchemaV3.self),
            migrationPlan: FieldNotesMigrationPlan.self,
            configurations: ModelConfiguration()
        )
    }

    static func open(
        using makeContainer: () throws -> ModelContainer = liveContainer
    ) -> Result<ModelContainer, FieldNotesLaunchFailure> {
        do {
            return .success(try makeContainer())
        } catch {
            return .failure(FieldNotesLaunchFailure(
                message: "Your notes could not be opened. FieldNotes did not create an empty replacement."
            ))
        }
    }
}

struct FieldNotesLaunchFailure: Error, Sendable, Equatable {
    let message: String
}
