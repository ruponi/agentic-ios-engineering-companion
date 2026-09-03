import Foundation

struct NoteSummary: Identifiable, Hashable, Sendable, Decodable {
    let id: UUID
    let title: String
    let excerpt: String
    let modifiedAt: Date

    static let samples = [
        NoteSummary(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Tide-pool observations",
            excerpt: "Anemones remained open after the cloud cover arrived.",
            modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ),
        NoteSummary(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Questions for the archive",
            excerpt: "Confirm the date on the handwritten survey map.",
            modifiedAt: Date(timeIntervalSince1970: 1_699_000_000)
        ),
    ]
}

enum NotesScreenState: Equatable {
    case loading
    case empty
    case error(message: String)
    case loaded(notes: [NoteSummary])
    case partial(notes: [NoteSummary], message: String)
}
