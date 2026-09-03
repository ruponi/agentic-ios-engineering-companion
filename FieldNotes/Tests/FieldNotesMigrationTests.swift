import SwiftData
import XCTest
@testable import FieldNotes

/// The chapter's central claim, made checkable: yesterday's store survives
/// today's schema. A green build proves declarations compile. A fresh install
/// proves an empty store opens. Neither proves this.
final class FieldNotesMigrationTests: XCTestCase {
    func testV1StoreMigratesWithoutLosingNote() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("FieldNotes.store")
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

        try seedV1(at: storeURL, id: id, createdAt: createdAt)

        // Open the SAME FILE as V3, through both lightweight stages.
        let container = try ModelContainer(
            for: Schema(versionedSchema: FieldNotesSchemaV3.self),
            migrationPlan: FieldNotesMigrationPlan.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let context = ModelContext(container)
        let notes = try context.fetch(FetchDescriptor<StoredNote>())

        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].id, id)
        XCTAssertEqual(notes[0].title, "Harbor observations")
        XCTAssertEqual(notes[0].body, "Three gulls returned at low tide.")
        XCTAssertEqual(notes[0].createdAt, createdAt)
        XCTAssertNil(notes[0].modifiedAt)
        XCTAssertNil(notes[0].serverRevision)
        XCTAssertNil(notes[0].lastSyncedBody)
    }

    func testDeletingNoteCascadesToPersonalContext() async throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: FieldNotesSchemaV3.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let noteID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        do {
            let context = ModelContext(container)
            context.insert(StoredNote(
                id: noteID,
                title: "Coffee order",
                body: "My usual is an oat latte.",
                createdAt: now,
                modifiedAt: now
            ))
            context.insert(StoredPersonalContext(
                id: UUID(),
                value: "Usual drink: oat latte",
                sourceNoteID: noteID,
                derivedAt: now,
                derivationVersion: "usual-order/v1",
                expiresAt: now.addingTimeInterval(86_400)
            ))
            try context.save()
        }

        try await SwiftDataNoteStore(modelContainer: container).deleteNote(id: noteID)

        let verificationContext = ModelContext(container)
        XCTAssertTrue(try verificationContext.fetch(FetchDescriptor<StoredNote>()).isEmpty)
        XCTAssertTrue(
            try verificationContext.fetch(FetchDescriptor<StoredPersonalContext>()).isEmpty
        )
    }

    /// Opens the explicit V1 schema, not today's model by accident.
    private func seedV1(at url: URL, id: UUID, createdAt: Date) throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: FieldNotesSchemaV1.self),
            configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(container)
        context.insert(
            FieldNotesSchemaV1.StoredNote(
                id: id,
                title: "Harbor observations",
                body: "Three gulls returned at low tide.",
                createdAt: createdAt
            )
        )
        try context.save()
    }
}
