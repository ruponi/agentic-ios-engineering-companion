import Foundation

/// Whether repeating a request is safe, and on whose authority.
enum RetrySafety: Sendable, Equatable {
    /// Reads, and writes the server treats as naturally repeatable.
    case safe
    /// Repeating would perform the effect twice. Do not retry.
    case forbidden
    /// Safe only because a cooperating server recognises this key as a repeat.
    case idempotencyKey(String)
}

/// A request that records the type it expects back and whether it may be
/// retried, so the retry policy never has to guess from the HTTP verb.
struct NetworkRequest<Response>: Sendable {
    let url: URL
    let method: String
    let retrySafety: RetrySafety

    init(url: URL, method: String = "GET", retrySafety: RetrySafety = .safe) {
        self.url = url
        self.method = method
        self.retrySafety = retrySafety
    }

    var canRetry: Bool {
        switch retrySafety {
        case .safe, .idempotencyKey: true
        case .forbidden: false
        }
    }

    func urlRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if case .idempotencyKey(let key) = retrySafety {
            // Keep this header name and the duplicate-response retention window
            // aligned with the deployed FieldNotes backend.
            request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        return request
    }
}
