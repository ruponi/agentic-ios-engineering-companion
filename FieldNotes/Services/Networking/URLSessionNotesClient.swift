import Foundation

/// Actor-backed client that validates the HTTP response before trusting its
/// body, then decodes newline-delimited JSON into streamed `NoteSummary`
/// values. Cancellation is honoured between lines, not only between requests.
actor URLSessionNotesClient: NotesClient {
    private let baseURL: URL
    private let session: URLSession
    private let policy: RetryPolicy
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared, policy: RetryPolicy = RetryPolicy()) {
        self.baseURL = baseURL
        self.session = session
        self.policy = policy

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    nonisolated func notes() -> AsyncThrowingStream<NoteSummary, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.streamNotes(into: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func streamNotes(
        into continuation: AsyncThrowingStream<NoteSummary, Error>.Continuation
    ) async throws {
        let request = NetworkRequest<Void>(url: baseURL.appendingPathComponent("notes"))
        let (bytes, response) = try await session.bytes(for: request.urlRequest())
        try Self.validate(response)

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard !line.isEmpty else { continue }
            guard let data = line.data(using: .utf8) else { throw NotesClientError.decodingFailed }
            do {
                continuation.yield(try decoder.decode(NoteSummary.self, from: data))
            } catch {
                throw NotesClientError.decodingFailed
            }
        }
    }

    func serviceNotice() async throws -> String? {
        let request = NetworkRequest<String?>(url: baseURL.appendingPathComponent("status"))
        return try await policy.run(request) {
            let (data, response) = try await self.session.data(for: request.urlRequest())
            try Self.validate(response)
            let text = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw NotesClientError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw NotesClientError.unacceptableStatus(http.statusCode)
        }
    }
}
