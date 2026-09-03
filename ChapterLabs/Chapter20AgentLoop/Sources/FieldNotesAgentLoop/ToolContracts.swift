import Foundation

public enum ToolEffectClassification: String, Sendable, Codable, Equatable {
    case read
    case reversibleWrite
    case consequential
}
public protocol AgentTool: Sendable {
    associatedtype Arguments: Sendable & Codable & Equatable
    associatedtype Result: Sendable & Codable & Equatable

    static var name: String { get }
    static var effect: ToolEffectClassification { get }
    static var timeout: Duration { get }
}

public protocol ReadAgentTool: AgentTool {
    func call(_ arguments: Arguments) async throws -> Result
}

public enum RegisteredReadToolFailure: Error, Sendable, Equatable, CustomStringConvertible {
    case invalidArguments(tool: String)
    case timedOut(tool: String)

    public var description: String {
        switch self {
        case .invalidArguments(let tool): "invalidArguments(tool:\(tool))"
        case .timedOut(let tool): "timedOut(tool:\(tool))"
        }
    }
}

/// Type erasure lets the loop register any existing read-only `AgentTool`
/// without giving that tool access to write approval or provenance admission.
public struct RegisteredReadTool: Sendable {
    public let name: String
    public let effect: ToolEffectClassification
    public let timeout: Duration
    private let invoke: @Sendable (String) async throws -> String

    public init<T: ReadAgentTool>(_ tool: T) {
        precondition(T.effect == .read)
        name = T.name
        effect = T.effect
        timeout = T.timeout
        invoke = { argumentsJSON in
            guard let data = argumentsJSON.data(using: .utf8),
                  let arguments = try? JSONDecoder().decode(T.Arguments.self, from: data)
            else {
                throw RegisteredReadToolFailure.invalidArguments(tool: T.name)
            }
            let result = try await Self.withTimeout(T.timeout, tool: T.name) {
                try await tool.call(arguments)
            }
            let envelope = ToolResultEnvelope(sourceTool: T.name, data: result)
            let encoded = try JSONEncoder.registeredTool.encode(envelope)
            guard let text = String(data: encoded, encoding: .utf8) else {
                throw AgentLoopFailure.toolFailed("tool result was not UTF-8")
            }
            return text
        }
    }

    public func call(argumentsJSON: String) async throws -> String {
        try await invoke(argumentsJSON)
    }

    private static func withTimeout<Value: Sendable>(
        _ timeout: Duration,
        tool: String,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw RegisteredReadToolFailure.timedOut(tool: tool)
            }
            guard let value = try await group.next() else {
                throw RegisteredReadToolFailure.timedOut(tool: tool)
            }
            group.cancelAll()
            return value
        }
    }
}

public struct ToolResultEnvelope<Payload: Sendable & Codable & Equatable>:
    Sendable, Codable, Equatable
{
    public let boundary: String
    public let sourceTool: String
    public let data: Payload

    public init(sourceTool: String, data: Payload) {
        self.boundary = "untrusted-tool-data"
        self.sourceTool = sourceTool
        self.data = data
    }
}

private extension JSONEncoder {
    static var registeredTool: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public struct SavePackingBriefArguments: Sendable, Codable, Equatable {
    public let title: String
    public let items: [String]
    public let sourceNoteIDs: [UUID]

    public init(title: String, items: [String], sourceNoteIDs: [UUID]) {
        self.title = title
        self.items = items
        self.sourceNoteIDs = sourceNoteIDs
    }
}

public struct TagNoteArguments: Sendable, Codable, Equatable {
    public let noteID: UUID
    public let tag: String

    public init(noteID: UUID, tag: String) {
        self.noteID = noteID
        self.tag = tag
    }
}

public struct DeleteNoteArguments: Sendable, Codable, Equatable {
    public let noteID: UUID

    public init(noteID: UUID) { self.noteID = noteID }
}

public enum NoteWriteAction: Sendable, Codable, Equatable {
    case savePackingBrief(SavePackingBriefArguments)
    case tagNote(TagNoteArguments)
    case deleteNote(DeleteNoteArguments)
}

public struct PendingAction: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let callID: String
    public let idempotencyKey: UUID
    public let effect: ToolEffectClassification
    public let action: NoteWriteAction

    public init(
        id: UUID = UUID(),
        callID: String,
        idempotencyKey: UUID = UUID(),
        effect: ToolEffectClassification,
        action: NoteWriteAction
    ) {
        self.id = id
        self.callID = callID
        self.idempotencyKey = idempotencyKey
        self.effect = effect
        self.action = action
    }
}

public struct ApprovedAction: Sendable, Equatable {
    public let pendingID: UUID
    public let action: NoteWriteAction

    fileprivate init(pending: PendingAction) {
        self.pendingID = pending.id
        self.action = pending.action
    }
}

public struct PendingActionAmendment: Sendable, Equatable {
    public let original: PendingAction
    public let pending: PendingAction
    public let trace: [TraceEvent]

    public init(original: PendingAction) {
        self.original = original
        self.pending = original
        self.trace = [TraceEvent("OBSERVE", "proposal pending=\(original.id)")]
    }

    private init(original: PendingAction, pending: PendingAction, trace: [TraceEvent]) {
        self.original = original
        self.pending = pending
        self.trace = trace
    }

    public func replacingAction(with action: NoteWriteAction) -> Self {
        let replacement = PendingAction(
            callID: pending.callID,
            effect: pending.effect,
            action: action
        )
        return Self(
            original: original,
            pending: replacement,
            trace: trace + [
                TraceEvent(
                    "DECIDE",
                    "amended old=\(pending.id) new=\(replacement.id)"
                ),
                TraceEvent(
                    "VERIFY",
                    "new-idempotency-key=\(replacement.idempotencyKey)"
                )
            ]
        )
    }

    public func approve(pendingID: UUID) throws -> ApprovedAction {
        guard pendingID == pending.id else {
            throw ActionValidationFailure.supersededPendingAction
        }
        return ApprovedAction(pending: pending)
    }
}

public struct AppliedChange: Sendable, Codable, Equatable {
    public let id: UUID
    public let pendingID: UUID
    public let idempotencyKey: UUID
    public let action: NoteWriteAction
    public let replayed: Bool

    public init(
        id: UUID,
        pendingID: UUID,
        idempotencyKey: UUID,
        action: NoteWriteAction,
        replayed: Bool
    ) {
        self.id = id
        self.pendingID = pendingID
        self.idempotencyKey = idempotencyKey
        self.action = action
        self.replayed = replayed
    }
}

public enum ActionValidationFailure: Error, Sendable, Equatable, CustomStringConvertible {
    case approvalMismatch
    case supersededPendingAction
    case invalidProductRule(String)
    case idempotencyConflict
    case unknownChange
    case consequentialActionNotRegistered

    public var description: String {
        switch self {
        case .approvalMismatch: "approvalMismatch"
        case .supersededPendingAction: "supersededPendingAction"
        case .invalidProductRule(let rule): "invalidProductRule(\(rule))"
        case .idempotencyConflict: "idempotencyConflict"
        case .unknownChange: "unknownChange"
        case .consequentialActionNotRegistered: "consequentialActionNotRegistered"
        }
    }
}
