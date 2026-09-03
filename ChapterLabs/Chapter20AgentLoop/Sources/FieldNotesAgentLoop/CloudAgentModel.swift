import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum CloudPurpose: String, Sendable, Codable, Equatable {
    case packingBrief
}

public struct CloudConsentGrant: Sendable, Equatable {
    fileprivate let id: UUID
    public let purpose: CloudPurpose

    fileprivate init(id: UUID, purpose: CloudPurpose) {
        self.id = id
        self.purpose = purpose
    }
}

public enum CloudConsentFailure: Error, Sendable, Equatable {
    case notActive
    case revoked
}

private struct CloudConsentLease: Sendable {
    let id: UUID
    let grantID: UUID
    let revocations: AsyncStream<Void>
}

public actor CloudConsentLedger {
    private var grants: [UUID: CloudPurpose] = [:]
    private var listeners: [UUID: [UUID: AsyncStream<Void>.Continuation]] = [:]

    public init() {}

    public func grant(_ purpose: CloudPurpose) -> CloudConsentGrant {
        let id = UUID()
        grants[id] = purpose
        return CloudConsentGrant(id: id, purpose: purpose)
    }

    public func revoke(_ grant: CloudConsentGrant) {
        grants.removeValue(forKey: grant.id)
        if let activeListeners = listeners.removeValue(forKey: grant.id) {
            for listener in activeListeners.values {
                listener.yield()
                listener.finish()
            }
        }
    }

    public func validate(_ grant: CloudConsentGrant) throws {
        guard grants[grant.id] == grant.purpose else {
            throw CloudConsentFailure.notActive
        }
    }

    fileprivate func begin(_ grant: CloudConsentGrant) throws -> CloudConsentLease {
        try validate(grant)

        let leaseID = UUID()
        var captured: AsyncStream<Void>.Continuation?
        let stream = AsyncStream<Void> { continuation in
            captured = continuation
        }
        guard let continuation = captured else {
            throw CloudConsentFailure.notActive
        }
        listeners[grant.id, default: [:]][leaseID] = continuation
        return CloudConsentLease(id: leaseID, grantID: grant.id, revocations: stream)
    }

    fileprivate func end(_ lease: CloudConsentLease) {
        listeners[lease.grantID]?[lease.id]?.finish()
        listeners[lease.grantID]?.removeValue(forKey: lease.id)
        if listeners[lease.grantID]?.isEmpty == true {
            listeners.removeValue(forKey: lease.grantID)
        }
    }
}

public struct CloudPackingRequest: Sendable, Codable, Equatable {
    public let capability: String
    public let purpose: CloudPurpose
    public let request: String
    public let selectedExcerpt: String?
    public let sourceNoteID: String?
    public let promptVersion: String
}

public struct CloudPayloadMinimizer: Sendable {
    public let maximumExcerptCharacters: Int

    public init(maximumExcerptCharacters: Int = 160) {
        precondition(maximumExcerptCharacters > 0)
        self.maximumExcerptCharacters = maximumExcerptCharacters
    }

    public func makePayload(
        from context: AgentContext,
        promptVersion: PromptVersion
    ) throws -> CloudPackingRequest {
        let request = context.messages.first(where: { $0.role == .user })?.content ?? ""
        let document = try context.messages
            .last(where: { $0.role == .tool })
            .flatMap(decodeFirstDocument)

        return CloudPackingRequest(
            capability: "packing-brief",
            purpose: .packingBrief,
            request: request,
            selectedExcerpt: document.map {
                String($0.body.prefix(maximumExcerptCharacters))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            },
            sourceNoteID: document?.id.uuidString,
            promptVersion: promptVersion.rawValue
        )
    }

    private func decodeFirstDocument(from message: AgentMessage) throws -> SearchDocument? {
        guard let data = message.content.data(using: .utf8) else { return nil }
        return try JSONDecoder.iso8601.decode(
            ToolResultEnvelope<[SearchDocument]>.self,
            from: data
        ).data.first
    }
}

public struct CloudWireProposal: Sendable, Codable, Equatable {
    public let action: String
    public let callID: String?
    public let query: String?
    public let title: String?
    public let items: [String]?
    public let sourceNoteIDs: [String]?

    public init(
        action: String,
        callID: String? = nil,
        query: String? = nil,
        title: String? = nil,
        items: [String]? = nil,
        sourceNoteIDs: [String]? = nil
    ) {
        self.action = action
        self.callID = callID
        self.query = query
        self.title = title
        self.items = items
        self.sourceNoteIDs = sourceNoteIDs
    }
}

public struct CloudStreamEnvelope: Sendable, Codable, Equatable {
    public let kind: String
    public let message: String?
    public let proposal: CloudWireProposal?
    public let providerIdentifier: String?
    public let modelIdentifier: String?
    public let correlationIdentifier: String

    public init(
        kind: String,
        message: String? = nil,
        proposal: CloudWireProposal? = nil,
        providerIdentifier: String? = nil,
        modelIdentifier: String? = nil,
        correlationIdentifier: String
    ) {
        self.kind = kind
        self.message = message
        self.proposal = proposal
        self.providerIdentifier = providerIdentifier
        self.modelIdentifier = modelIdentifier
        self.correlationIdentifier = correlationIdentifier
    }
}

public enum CloudAdapterFailure: Error, Sendable, Equatable {
    case invalidResponse
    case unacceptableStatus(Int)
    case schemaRejected(String)
}

public protocol CloudProposalTransport: Sendable {
    func events(
        for payload: CloudPackingRequest,
        idempotencyKey: String,
        correlationIdentifier: String
    ) async -> AsyncThrowingStream<CloudStreamEnvelope, Error>
}

public enum RetrySafety: Sendable, Equatable {
    case safe
    case forbidden
    case idempotencyKey(String)
}

public struct NetworkRequest<Response>: Sendable {
    public let url: URL
    public let method: String
    public let retrySafety: RetrySafety

    public init(url: URL, method: String, retrySafety: RetrySafety) {
        self.url = url
        self.method = method
        self.retrySafety = retrySafety
    }

    public var canRetry: Bool {
        switch retrySafety {
        case .safe, .idempotencyKey: true
        case .forbidden: false
        }
    }
}

public struct RetryPolicy: Sendable {
    public let maximumAttempts: Int
    public let initialDelay: Duration

    public init(maximumAttempts: Int = 3, initialDelay: Duration = .milliseconds(100)) {
        self.maximumAttempts = maximumAttempts
        self.initialDelay = initialDelay
    }

    public func run<Response: Sendable>(
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
                guard Self.isTransient(error),
                      request.canRetry,
                      attempt < maximumAttempts else { throw error }
                try await Task.sleep(for: delay)
                delay *= 2
                attempt += 1
            }
        }
    }

    private static func isTransient(_ error: Error) -> Bool {
        if let failure = error as? CloudAdapterFailure,
           case .unacceptableStatus(let status) = failure {
            return status == 408 || status == 429 || (500...599).contains(status)
        }
        if let failure = error as? URLError {
            return [
                .timedOut, .cannotFindHost, .cannotConnectToHost,
                .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet,
            ].contains(failure.code)
        }
        return false
    }
}

public actor URLSessionCloudProposalTransport: CloudProposalTransport {
    private let endpoint: URL
    private let userAccessToken: String
    private let session: URLSession
    private let retryPolicy: RetryPolicy

    public init(
        endpoint: URL,
        userAccessToken: String,
        session: URLSession = .shared,
        retryPolicy: RetryPolicy = RetryPolicy()
    ) {
        self.endpoint = endpoint
        self.userAccessToken = userAccessToken
        self.session = session
        self.retryPolicy = retryPolicy
    }

    public func events(
        for payload: CloudPackingRequest,
        idempotencyKey: String,
        correlationIdentifier: String
    ) async -> AsyncThrowingStream<CloudStreamEnvelope, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = NetworkRequest<Void>(
                        url: endpoint,
                        method: "POST",
                        retrySafety: .idempotencyKey(idempotencyKey)
                    )
                    try await retryPolicy.run(request) {
                        try await self.streamOnce(
                            payload: payload,
                            idempotencyKey: idempotencyKey,
                            correlationIdentifier: correlationIdentifier,
                            into: continuation
                        )
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func streamOnce(
        payload: CloudPackingRequest,
        idempotencyKey: String,
        correlationIdentifier: String,
        into continuation: AsyncThrowingStream<CloudStreamEnvelope, Error>.Continuation
    ) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder.stable.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(userAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        request.setValue(correlationIdentifier, forHTTPHeaderField: "X-Correlation-ID")

        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw CloudAdapterFailure.invalidResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw CloudAdapterFailure.unacceptableStatus(response.statusCode)
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
            continuation.yield(try JSONDecoder().decode(CloudStreamEnvelope.self, from: data))
        }
    }
}

public actor CloudAgentModel: AgentModel {
    private let grant: CloudConsentGrant
    private let consentLedger: CloudConsentLedger
    private let transport: any CloudProposalTransport
    private let minimizer: CloudPayloadMinimizer
    private let promptVersion: PromptVersion
    private let progress: @Sendable (String) -> Void

    public private(set) var runRecord: ModelRunRecord?

    public init(
        grant: CloudConsentGrant,
        consentLedger: CloudConsentLedger,
        transport: any CloudProposalTransport,
        minimizer: CloudPayloadMinimizer = CloudPayloadMinimizer(),
        promptVersion: PromptVersion = .packingBriefV1,
        progress: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        precondition(grant.purpose == .packingBrief)
        self.grant = grant
        self.consentLedger = consentLedger
        self.transport = transport
        self.minimizer = minimizer
        self.promptVersion = promptVersion
        self.progress = progress
    }

    public func respond(to context: AgentContext) async throws -> AgentProposal {
        let lease = try await consentLedger.begin(grant)
        do {
            let payload = try minimizer.makePayload(from: context, promptVersion: promptVersion)
            let idempotencyKey = StableRequestIdentifier.make(from: payload)
            let correlationIdentifier = UUID().uuidString
            let response = try await raceResponseAgainstRevocation(
                payload: payload,
                idempotencyKey: idempotencyKey,
                correlationIdentifier: correlationIdentifier,
                lease: lease
            )
            runRecord = ModelRunRecord(
                promptVersion: promptVersion,
                operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                providerIdentifier: response.providerIdentifier,
                modelIdentifier: response.modelIdentifier,
                correlationIdentifier: correlationIdentifier
            )
            await consentLedger.end(lease)
            return response.proposal
        } catch {
            await consentLedger.end(lease)
            throw error
        }
    }

    private func raceResponseAgainstRevocation(
        payload: CloudPackingRequest,
        idempotencyKey: String,
        correlationIdentifier: String,
        lease: CloudConsentLease
    ) async throws -> CloudResponse {
        try await withThrowingTaskGroup(of: CloudResponse.self) { group in
            let transport = self.transport
            let progress = self.progress
            group.addTask {
                let events = await transport.events(
                    for: payload,
                    idempotencyKey: idempotencyKey,
                    correlationIdentifier: correlationIdentifier
                )
                return try await Self.consume(events, progress: progress)
            }
            group.addTask {
                for await _ in lease.revocations {
                    throw CloudConsentFailure.revoked
                }
                throw CloudConsentFailure.revoked
            }

            guard let first = try await group.next() else {
                throw CloudAdapterFailure.invalidResponse
            }
            group.cancelAll()
            return first
        }
    }

    private nonisolated static func consume(
        _ events: AsyncThrowingStream<CloudStreamEnvelope, Error>,
        progress: @Sendable (String) -> Void
    ) async throws -> CloudResponse {
        for try await event in events {
            try Task.checkCancellation()
            if event.kind == "progress", let message = event.message {
                progress(message)
                continue
            }
            if event.kind == "proposal",
               let wire = event.proposal,
               let provider = event.providerIdentifier,
               let model = event.modelIdentifier {
                return CloudResponse(
                    proposal: try CloudProposalMapper.map(wire),
                    providerIdentifier: provider,
                    modelIdentifier: model
                )
            }
        }
        throw CloudAdapterFailure.invalidResponse
    }
}

private struct CloudResponse: Sendable {
    let proposal: AgentProposal
    let providerIdentifier: String
    let modelIdentifier: String
}

public enum CloudProposalMapper {
    public static func map(_ wire: CloudWireProposal) throws -> AgentProposal {
        switch wire.action {
        case "searchNotes":
            guard let callID = wire.callID, let query = wire.query else {
                throw CloudAdapterFailure.schemaRejected("missing search fields")
            }
            return try GuidedProposalMapper.map(.search(callID: callID, query: query))
        case "finish":
            guard let title = wire.title,
                  let items = wire.items,
                  let sourceNoteIDs = wire.sourceNoteIDs else {
                throw CloudAdapterFailure.schemaRejected("missing final fields")
            }
            return try GuidedProposalMapper.map(.finish(
                title: title,
                items: items,
                sourceNoteIDs: sourceNoteIDs
            ))
        default:
            throw CloudAdapterFailure.schemaRejected("unknown action")
        }
    }
}

private enum StableRequestIdentifier {
    static func make(from payload: CloudPackingRequest) -> String {
        let data = (try? JSONEncoder.stable.encode(payload)) ?? Data()
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "packing-brief-\(String(hash, radix: 16))"
    }
}

private extension JSONEncoder {
    static var stable: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
