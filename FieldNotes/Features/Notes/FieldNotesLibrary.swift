import Foundation
import Observation

@MainActor
@Observable
final class FieldNotesLibrary {
    private(set) var state: NotesScreenState = .loading
    var query = ""
    private let loader: NotesLoader
    private var loadingNotes: [NoteSummary] = []
    private var loadingWarning: String?

    init(store: any NoteStore, client: (any NotesClient)? = nil) {
        loader = NotesLoader(store: store, client: client)
    }

    func reload() async {
        state = .loading
        loadingNotes = []
        loadingWarning = nil

        do {
            try await loader.load { [weak self] event in
                await self?.receive(event)
            }
        } catch is CancellationError {
            return
        } catch {
            state = .error(message: "The note library could not be read.")
            return
        }

        state = Self.resolve(notes: loadingNotes, warning: loadingWarning)
    }

    /// Debounced so fast typing does not rebuild results per keystroke. The
    /// equality guard rejects a stale result from a slow dependency.
    func search() async {
        let requested = query

        do {
            try await Task.sleep(for: .milliseconds(150))
            let notes = try await loader.search(requested)
            try Task.checkCancellation()
            guard requested == query else { return }
            state = notes.isEmpty ? .empty : .loaded(notes: notes)
        } catch is CancellationError {
            return
        } catch {
            state = .error(message: "FieldNotes could not search saved notes.")
        }
    }

    func note(id: UUID) -> NoteSummary? {
        switch state {
        case .loaded(let notes), .partial(let notes, _):
            notes.first { $0.id == id }
        case .loading, .empty, .error:
            nil
        }
    }

    private static func resolve(notes: [NoteSummary], warning: String?) -> NotesScreenState {
        switch (notes.isEmpty, warning) {
        case (true, let message?): .error(message: message)
        case (true, nil): .empty
        case (false, let message?): .partial(notes: notes, message: message)
        case (false, nil): .loaded(notes: notes)
        }
    }

    private func receive(_ event: NotesLoadEvent) {
        switch event {
        case .note(let note): loadingNotes.append(note)
        case .warning(let message): loadingWarning = message
        }
        state = Self.resolve(notes: loadingNotes, warning: loadingWarning)
    }
}
