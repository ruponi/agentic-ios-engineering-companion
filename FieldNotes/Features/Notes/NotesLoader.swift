import Foundation

enum NotesLoadEvent: Sendable, Equatable {
    case note(NoteSummary)
    case warning(String)
}

/// Combines the durable store and the network client under one lifetime.
///
/// Saved notes are emitted BEFORE the network is consulted. A failed request
/// becomes a freshness warning when useful local content exists; it can never
/// erase the list.
struct NotesLoader: Sendable {
    let store: any NoteStore
    let client: (any NotesClient)?

    init(store: any NoteStore, client: (any NotesClient)? = nil) {
        self.store = store
        self.client = client
    }

    func load(_ receive: @Sendable (NotesLoadEvent) async -> Void) async throws {
        let saved = try await store.summaries(matching: "")
        for note in saved {
            try Task.checkCancellation()
            await receive(.note(note))
        }

        guard let client else { return }

        do {
            if let message = try await client.serviceNotice() {
                await receive(.warning(message))
            }
        } catch {
            try Task.checkCancellation()
            if !saved.isEmpty {
                await receive(.warning("Showing saved notes. Sync is unavailable."))
            }
        }
    }

    /// Search never touches the network.
    func search(_ query: String) async throws -> [NoteSummary] {
        try await store.summaries(matching: query)
    }
}
