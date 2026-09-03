import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public struct PromptVersion: RawRepresentable, Sendable, Codable, Equatable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let packingBriefV1 = PromptVersion(rawValue: "packing-brief/v1")
}

public struct ModelRunRecord: Sendable, Codable, Equatable {
    public let promptVersion: PromptVersion
    public let operatingSystemVersion: String
    public let providerIdentifier: String?
    public let modelIdentifier: String?
    public let correlationIdentifier: String?

    public init(
        promptVersion: PromptVersion,
        operatingSystemVersion: String,
        providerIdentifier: String? = nil,
        modelIdentifier: String? = nil,
        correlationIdentifier: String? = nil
    ) {
        self.promptVersion = promptVersion
        self.operatingSystemVersion = operatingSystemVersion
        self.providerIdentifier = providerIdentifier
        self.modelIdentifier = modelIdentifier
        self.correlationIdentifier = correlationIdentifier
    }
}

public enum FoundationAdapterFailure: Error, Sendable, Equatable, CustomStringConvertible {
    case schemaRejected(String)
    case invalidSourceNoteID(String)

    public var description: String {
        switch self {
        case .schemaRejected(let detail):
            "schemaRejected(\(detail))"
        case .invalidSourceNoteID(let value):
            "invalidSourceNoteID(\(value))"
        }
    }
}

public enum GuidedProposalPayload: Sendable, Equatable {
    case search(callID: String, query: String)
    case finish(title: String, items: [String], sourceNoteIDs: [String])
}

public enum GuidedProposalMapper {
    public static func map(_ payload: GuidedProposalPayload) throws -> AgentProposal {
        switch payload {
        case .search(let callID, let query):
            let arguments = try JSONEncoder().encode(SearchArguments(query: query))
            guard let argumentsJSON = String(data: arguments, encoding: .utf8) else {
                throw FoundationAdapterFailure.schemaRejected("search arguments were not UTF-8")
            }
            return .toolCall(ToolCall(
                id: callID,
                name: "searchNotes",
                argumentsJSON: argumentsJSON
            ))

        case .finish(let title, let items, let sourceNoteIDs):
            let ids = try sourceNoteIDs.map { value in
                guard let id = UUID(uuidString: value) else {
                    throw FoundationAdapterFailure.invalidSourceNoteID(value)
                }
                return id
            }
            return .final(PackingBrief(title: title, items: items, sourceNoteIDs: ids))
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
private enum GeneratedAgentAction {
    case searchNotes(GeneratedSearchRequest)
    case finish(GeneratedPackingBrief)
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
private struct GeneratedSearchRequest {
    @Guide(description: "A unique identifier for this tool call")
    var callID: String

    @Guide(description: "A short query for the person's notes")
    var query: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
private struct GeneratedPackingBrief {
    @Guide(description: "A short title for the packing brief")
    var title: String

    @Guide(description: "Concrete packing items", .count(1...6))
    var items: [String]

    @Guide(description: "UUID strings copied only from note search results")
    var sourceNoteIDs: [String]
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
public actor FoundationModelsAgentModel: AgentModel {
    public let runRecord: ModelRunRecord

    public init(
        promptVersion: PromptVersion = .packingBriefV1,
        operatingSystemVersion: String = ProcessInfo.processInfo.operatingSystemVersionString
    ) {
        self.runRecord = ModelRunRecord(
            promptVersion: promptVersion,
            operatingSystemVersion: operatingSystemVersion
        )
    }

    private var warmSession: (instructions: String, session: LanguageModelSession)?

    /// Called when the packing screen appears, not when the answer is needed.
    /// Prewarming one line above `respond` costs a call and buys nothing.
    public func prepare(instructions: String) {
        let session = makeSession(instructions: instructions)
        session.prewarm()
        warmSession = (instructions, session)
    }

    public func respond(to context: AgentContext) async throws -> AgentProposal {
        let session: LanguageModelSession
        if let warm = warmSession, warm.instructions == context.instructions {
            session = warm.session
        } else {
            session = makeSession(instructions: context.instructions)
        }
        warmSession = nil

        let prompt = render(context)

        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedAgentAction.self
            )
            return try GuidedProposalMapper.map(response.content.payload)
        } catch LanguageModelSession.GenerationError.decodingFailure(let failureContext) {
            throw FoundationAdapterFailure.schemaRejected(failureContext.debugDescription)
        }
    }

    private func makeSession(instructions: String) -> LanguageModelSession {
        let version = runRecord.promptVersion.rawValue
        return LanguageModelSession {
            "Prompt version: \(version)"
            instructions
            "Return one action. Search before finishing. Copy source UUIDs exactly from tool results."
        }
    }

    private func render(_ context: AgentContext) -> String {
        let messages = context.messages.map { message in
            "\(message.role.rawValue): \(message.content)"
        }.joined(separator: "\n")
        return """
        Registered tools: \(context.availableTools.joined(separator: ", "))
        Conversation:
        \(messages)
        """
    }
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
private extension GeneratedAgentAction {
    var payload: GuidedProposalPayload {
        switch self {
        case .searchNotes(let request):
            .search(callID: request.callID, query: request.query)
        case .finish(let brief):
            .finish(
                title: brief.title,
                items: brief.items,
                sourceNoteIDs: brief.sourceNoteIDs
            )
        }
    }
}
#endif
