import Foundation

public enum MessageRole: String, Sendable, Codable {
    case system
    case user
    case assistant
    case tool
}

public struct AgentMessage: Sendable, Codable, Equatable {
    public let role: MessageRole
    public let content: String

    public init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AgentContext: Sendable, Equatable {
    public let instructions: String
    public let messages: [AgentMessage]
    public let availableTools: [String]

    public init(instructions: String, messages: [AgentMessage], availableTools: [String]) {
        self.instructions = instructions
        self.messages = messages
        self.availableTools = availableTools
    }
}

public struct ToolCall: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let argumentsJSON: String

    public init(id: String, name: String, argumentsJSON: String) {
        self.id = id
        self.name = name
        self.argumentsJSON = argumentsJSON
    }
}

public struct PackingBrief: Sendable, Codable, Equatable {
    public let title: String
    public let items: [String]
    public let sourceNoteIDs: [UUID]

    public init(title: String, items: [String], sourceNoteIDs: [UUID]) {
        self.title = title
        self.items = items
        self.sourceNoteIDs = sourceNoteIDs
    }
}

public enum AgentProposal: Sendable, Equatable {
    case toolCall(ToolCall)
    case final(PackingBrief)
}

public protocol AgentModel: Sendable {
    func respond(to context: AgentContext) async throws -> AgentProposal
}

public enum ModelUnavailability: String, Error, Sendable, Equatable, CustomStringConvertible {
    case frameworkNotPresent
    case appleIntelligenceNotEnabled

    public var description: String { rawValue }
}

public enum AgentLoopFailure: Error, Sendable, Equatable, CustomStringConvertible {
    case unknownTool(String)
    case malformedArguments
    case invalidToolArguments(name: String, reason: String)
    case duplicateCallID(String)
    case repeatedToolCall
    case toolResultTooLarge(limit: Int)
    case toolFailed(String)
    case invalidFinalProvenance
    case invalidFinalContent
    case modelUnavailable(ModelUnavailability)
    case modelIneligible
    case modelNotReady
    case modelFailed(String)

    public var description: String {
        switch self {
        case .unknownTool(let name): "unknownTool(\(name))"
        case .malformedArguments: "malformedArguments"
        case .invalidToolArguments(let name, let reason):
            "invalidToolArguments(name:\(name),reason:\(reason))"
        case .duplicateCallID(let id): "duplicateCallID(\(id))"
        case .repeatedToolCall: "repeatedToolCall"
        case .toolResultTooLarge(let limit): "toolResultTooLarge(limit:\(limit))"
        case .toolFailed(let message): "toolFailed(\(message))"
        case .invalidFinalProvenance: "invalidFinalProvenance"
        case .invalidFinalContent: "invalidFinalContent"
        case .modelUnavailable(let reason): "modelUnavailable(\(reason))"
        case .modelIneligible: "modelIneligible"
        case .modelNotReady: "modelNotReady"
        case .modelFailed(let message): "modelFailed(\(message))"
        }
    }
}

public struct SuspendedAgentRun: Sendable, Equatable {
    public let pending: PendingAction
    public let trace: [TraceEvent]

    public init(pending: PendingAction, trace: [TraceEvent]) {
        self.pending = pending
        self.trace = trace
    }

    /// Carries an amended proposal back across the suspension boundary. The
    /// replacement keeps the run history but makes the superseded action
    /// impossible to approve through this run.
    public func replacingPending(
        with amendment: PendingActionAmendment
    ) throws -> SuspendedAgentRun {
        guard amendment.original.id == pending.id else {
            throw ActionValidationFailure.approvalMismatch
        }
        return SuspendedAgentRun(
            pending: amendment.pending,
            trace: trace + amendment.trace.dropFirst()
        )
    }
}

public struct TraceEvent: Sendable, Equatable, CustomStringConvertible {
    public let stage: String
    public let detail: String

    public init(_ stage: String, _ detail: String) {
        self.stage = stage
        self.detail = detail
    }

    public var description: String { "\(stage) \(detail)" }
}

public enum AgentLoopOutcome: Sendable, Equatable {
    case succeeded(PackingBrief, trace: [TraceEvent])
    case failed(AgentLoopFailure, trace: [TraceEvent])
    case cancelled(trace: [TraceEvent])
    case turnLimitReached(trace: [TraceEvent])
    case suspended(SuspendedAgentRun)
    case changeApplied(AppliedChange, trace: [TraceEvent])
    case declined(PendingAction, trace: [TraceEvent])

    public var trace: [TraceEvent] {
        switch self {
        case .succeeded(_, let trace), .failed(_, let trace), .cancelled(let trace),
             .turnLimitReached(let trace), .changeApplied(_, let trace), .declined(_, let trace):
            trace
        case .suspended(let run): run.trace
        }
    }
}
