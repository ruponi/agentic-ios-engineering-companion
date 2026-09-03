import Foundation

/// The typed network boundary for FieldNotes.
///
/// `notes()` streams summaries so a slow response still fills the list
/// progressively. `serviceNotice()` is optional status text; its failure is a
/// freshness problem, never a reason to hide saved notes.
protocol NotesClient: Sendable {
    func notes() -> AsyncThrowingStream<NoteSummary, Error>
    func serviceNotice() async throws -> String?
}

enum NotesClientError: Error, Equatable {
    case invalidResponse
    case unacceptableStatus(Int)
    case decodingFailed

    /// Only these justify a retry. A 4xx will fail identically forever.
    var isTransient: Bool {
        switch self {
        case .invalidResponse: false
        case .decodingFailed: false
        case .unacceptableStatus(let code): code == 408 || code == 429 || (500...599).contains(code)
        }
    }
}
