import Observation
import SwiftUI

enum FieldNotesRoute: Hashable {
    case note(UUID)
}

enum FieldNotesSheet: String, Identifiable {
    case capture

    var id: String { rawValue }
}

@MainActor
@Observable
final class FieldNotesRouter {
    var path: [FieldNotesRoute] = []
    var presentedSheet: FieldNotesSheet?

    func open(_ note: NoteSummary) {
        path.append(.note(note.id))
    }
}

struct FieldNotesRootView: View {
    private let store: any NoteStore
    @State private var library: FieldNotesLibrary
    @State private var router = FieldNotesRouter()

    init(store: any NoteStore) {
        self.store = store
        _library = State(initialValue: FieldNotesLibrary(store: store))
    }

    var body: some View {
        @Bindable var router = router
        @Bindable var library = library

        NavigationStack(path: $router.path) {
            NotesListView(
                state: library.state,
                onOpen: router.open,
                onRetry: { Task { await library.reload() } },
                onCreate: { router.presentedSheet = .capture }
            )
            .searchable(text: $library.query, prompt: "Search Notes")
            .navigationDestination(for: FieldNotesRoute.self) { route in
                switch route {
                case .note(let id):
                    if let note = library.note(id: id) {
                        NoteDetailView(note: note)
                    } else {
                        ContentUnavailableView(
                            "Note Unavailable",
                            systemImage: "note.text",
                            description: Text("This note is no longer in the current library.")
                        )
                    }
                }
            }
        }
        .sheet(item: $router.presentedSheet) { sheet in
            switch sheet {
            case .capture:
                CaptureView(store: store, library: library)
            }
        }
        .task { await library.reload() }
        .task(id: library.query) {
            guard !library.query.isEmpty else { return }
            await library.search()
        }
    }
}

#Preview("FieldNotes") {
    FieldNotesRootView(store: InMemoryNoteStore.seeded())
}
