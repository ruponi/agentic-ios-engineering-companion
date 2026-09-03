import Foundation

/// Retries only classified transient failures, and only for requests that say
/// repeating them is safe. Cancellation is checked before each attempt, after
/// each failure, and during the wait.
struct RetryPolicy: Sendable {
    let maximumAttempts: Int
    let initialDelay: Duration

    // Example defaults. Choose and test production limits, bounded jitter, and
    // `Retry-After` handling before shipping.
    init(maximumAttempts: Int = 3, initialDelay: Duration = .milliseconds(250)) {
        self.maximumAttempts = maximumAttempts
        self.initialDelay = initialDelay
    }

    func run<Response>(
        _ request: NetworkRequest<Response>,
        operation: @Sendable () async throws -> Response
    ) async throws -> Response {
        var attempt = 1
        var delay = initialDelay

        while true {
            try Task.checkCancellation()
            do {
                return try await operation()
            } catch {
                try Task.checkCancellation()

                let transient = (error as? NotesClientError)?.isTransient ?? false
                guard transient, request.canRetry, attempt < maximumAttempts else {
                    throw error
                }

                try await Task.sleep(for: delay)
                delay = delay * 2
                attempt += 1
            }
        }
    }
}
