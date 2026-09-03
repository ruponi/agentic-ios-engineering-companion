import Foundation
import Testing
@testable import FieldNotes

@Suite("FieldNotes core behavior")
struct FieldNotesTests {
    @MainActor
    @Test("whitespace remains visible and is not saved")
    func whitespaceValidation() async throws {
        let store = InMemoryNoteStore()
        let model = CaptureModel(service: store)
        model.text = "   \n"

        #expect(await model.save() == false)
        #expect(model.text == "   \n")
        #expect(model.validationMessage == "A note needs visible text.")
        #expect(try await store.notes().isEmpty)
    }

    @MainActor
    @Test("saving reloads the library")
    func saveAndReload() async throws {
        let store = InMemoryNoteStore()
        let capture = CaptureModel(service: store)
        let library = FieldNotesLibrary(store: store)
        capture.text = "Kyoto packing\nRain shell and notebook"

        #expect(await capture.save())
        await library.reload()

        guard case .loaded(let notes) = library.state else {
            Issue.record("Expected a loaded library")
            return
        }
        #expect(notes.map(\.title) == ["Kyoto packing"])
    }

    @MainActor
    @Test("typed lookup resolves only loaded notes")
    func typedLookup() async {
        let store = InMemoryNoteStore.seeded()
        let library = FieldNotesLibrary(store: store)

        await library.reload()

        #expect(library.note(id: NoteSummary.samples[0].id) == NoteSummary.samples[0])
        #expect(library.note(id: UUID()) == nil)
    }
}
