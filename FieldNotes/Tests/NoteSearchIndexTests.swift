import Foundation
import XCTest
@testable import FieldNotes

final class NoteSearchIndexTests: XCTestCase {
    private let older = Date(timeIntervalSince1970: 1_699_000_000)
    private let newer = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeIndex() -> (NoteSearchIndex, UUID, UUID) {
        let harbor = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let archive = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        var index = NoteSearchIndex()
        index.rebuild(from: [
            SearchDocument(id: harbor, title: "Harbor observations",
                           body: "Three gulls returned at low tide.", modifiedAt: older),
            SearchDocument(id: archive, title: "Archive questions",
                           body: "Confirm the harbor survey date.", modifiedAt: newer),
        ])
        return (index, harbor, archive)
    }

    func testTitleMatchOutranksBodyMatch() {
        let (index, harbor, archive) = makeIndex()
        XCTAssertEqual(index.rankedIDs(for: "harbor"), [harbor, archive])
    }

    func testPrefixQueryMatches() {
        let (index, harbor, _) = makeIndex()
        XCTAssertTrue(index.rankedIDs(for: "harb").contains(harbor))
    }

    func testEveryQueryTokenMustMatch() {
        let (index, _, _) = makeIndex()
        XCTAssertTrue(index.rankedIDs(for: "harbor unicorn").isEmpty)
    }

    func testEmptyQueryReturnsNewestFirst() {
        let (index, harbor, archive) = makeIndex()
        XCTAssertEqual(index.rankedIDs(for: ""), [archive, harbor])
    }

    func testFoldingIgnoresCaseAndDiacritics() {
        let (index, harbor, _) = makeIndex()
        XCTAssertTrue(index.rankedIDs(for: "HÁRBOR").contains(harbor))
    }
}
