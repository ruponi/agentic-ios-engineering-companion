import Foundation
import FieldNotesAgentLoop

public struct AgentBudgetLimits: Sendable, Equatable {
    public let modelTurns = 4
    public let retainedMessages = 6
    public let toolResultCharacters = 2_000
    public let recoverableToolFailures = 1

    public init() {}
}

public struct AgentBudgetObservation: Sendable, Equatable {
    public let modelTurns: Int
    public let maximumRetainedMessages: Int
    public let toolResultCharacters: Int
    public let recoverableToolFailures: Int

    public init(
        modelTurns: Int,
        maximumRetainedMessages: Int,
        toolResultCharacters: Int,
        recoverableToolFailures: Int
    ) {
        self.modelTurns = modelTurns
        self.maximumRetainedMessages = maximumRetainedMessages
        self.toolResultCharacters = toolResultCharacters
        self.recoverableToolFailures = recoverableToolFailures
    }

    public func fits(_ limits: AgentBudgetLimits = AgentBudgetLimits()) -> Bool {
        modelTurns <= limits.modelTurns
            && maximumRetainedMessages <= limits.retainedMessages
            && toolResultCharacters <= limits.toolResultCharacters
            && recoverableToolFailures <= limits.recoverableToolFailures
    }
}

public enum AgentBudgetObserver {
    public static func canonicalRequest() async throws -> AgentBudgetObservation {
        let outcome = await AgentLoop(
            model: FieldNotesFixture.successfulModel(),
            searchTool: FieldNotesFixture.searchTool()
        ).run(request: FieldNotesFixture.request)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let envelope = ToolResultEnvelope(
            sourceTool: FieldNotesSearchTool.name,
            data: [FieldNotesFixture.documents[0]]
        )
        let characters = String(decoding: try encoder.encode(envelope), as: UTF8.self).count
        let trace = outcome.trace
        let retainedMessages = trace.compactMap { event -> Int? in
            guard let range = event.detail.range(of: "retained-messages=") else { return nil }
            return Int(event.detail[range.upperBound...].prefix { $0.isNumber })
        }.max() ?? 0

        return AgentBudgetObservation(
            modelTurns: trace.count { $0.stage == "DECIDE" && $0.detail.contains("turn=") },
            maximumRetainedMessages: retainedMessages,
            toolResultCharacters: characters,
            recoverableToolFailures: trace.count { $0.detail.contains("recoverable-error") }
        )
    }
}

public struct AgentCostObservation: Sendable, Equatable {
    public let requestBytes: Int
    public let responseBytes: Int
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let billedMicrodollars: Int?

    public init(
        requestBytes: Int,
        responseBytes: Int,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        billedMicrodollars: Int? = nil
    ) {
        self.requestBytes = requestBytes
        self.responseBytes = responseBytes
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.billedMicrodollars = billedMicrodollars
    }
}
