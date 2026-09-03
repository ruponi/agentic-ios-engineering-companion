import Foundation

/// The preview and test fixture. Production composition uses
/// `SwiftDataNoteStore`; this one deliberately forgets when the process ends,
/// which is exactly what makes it useful in previews.
actor InMemoryNoteStore: NoteStore {
    private var storedNotes: [NoteSummary]
    private var searchIndex = NoteSearchIndex()
    private var indexIsReady = false

    init(notes: [NoteSummary] = []) {
        storedNotes = notes
    }

    func notes() -> [NoteSummary] {
        storedNotes.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func summaries(matching query: String) -> [NoteSummary] {
        if !indexIsReady {
            searchIndex.rebuild(from: storedNotes.map {
                SearchDocument(id: $0.id, title: $0.title, body: $0.excerpt, modifiedAt: $0.modifiedAt)
            })
            indexIsReady = true
        }
        let notesByID = Dictionary(uniqueKeysWithValues: storedNotes.map { ($0.id, $0) })
        return searchIndex.rankedIDs(for: query).compactMap { notesByID[$0] }
    }

    /// The fixture stores no synchronisation metadata, so it can honestly
    /// report only insertion. Conflict behaviour belongs to the real store.
    func merge(_ remote: RemoteNote) -> MergeOutcome {
        guard !storedNotes.contains(where: { $0.id == remote.id }) else { return .unchanged }
        storedNotes.append(
            NoteSummary(
                id: remote.id,
                title: remote.title,
                excerpt: String(remote.body.prefix(160)),
                modifiedAt: remote.modifiedAt
            )
        )
        indexIsReady = false
        return .inserted
    }

    func save(_ draft: CaptureDraft) {
        let visibleText = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = visibleText.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Field Note"
        storedNotes.append(NoteSummary(
            id: UUID(),
            title: String(firstLine.prefix(60)),
            excerpt: visibleText,
            modifiedAt: Date()
        ))
        indexIsReady = false
    }

    static func seeded() -> InMemoryNoteStore {
        InMemoryNoteStore(notes: NoteSummary.samples)
    }
}
