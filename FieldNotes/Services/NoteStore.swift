import Foundation

/// A full note as it arrives from a cooperating server.
///
/// Deliberately larger than `NoteSummary`: an excerpt is not a body, and a
/// synchronisation decision must never be made from a truncated value.
struct RemoteNote: Sendable, Equatable {
    let id: UUID
    let title: String
    let body: String
    let modifiedAt: Date
    let revision: Int
}

enum MergeOutcome: String, Sendable, Equatable {
    case inserted
    case updated
    case unchanged
    case conflict
}

/// The durable note boundary. Implementations own storage; callers exchange
/// immutable `Sendable` values across it and never carry managed objects away.
protocol NoteStore: CaptureService {
    func notes() async throws -> [NoteSummary]
    func summaries(matching query: String) async throws -> [NoteSummary]
    func merge(_ remote: RemoteNote) async throws -> MergeOutcome
}
