import Foundation
import FieldNotesAgentLoop

public enum TelemetryStage: String, Sendable, Codable, CaseIterable, Equatable {
    case deviceRequest = "device.request"
    case backendAccepted = "backend.accepted"
    case modelCompleted = "model.completed"
    case toolCompleted = "tool.completed"
    case changeApplied = "change.applied"
    case deviceStopped = "device.stopped"
}

public struct AgentTelemetryEvent: Sendable, Codable, Equatable {
    public let sequence: Int
    public let correlationIdentifier: UUID
    public let stage: TelemetryStage
    public let durationMilliseconds: Int?
    public let count: Int?
    public let requestByteCount: Int?
    public let responseByteCount: Int?
    public let promptVersion: String?
    public let operatingSystemVersion: String?
    public let providerIdentifier: String?
    public let modelIdentifier: String?
    public let pendingIdentifier: UUID?
    public let changeIdentifier: UUID?
    public let replayed: Bool?
    public let outcome: String?

    public init(
        sequence: Int,
        correlationIdentifier: UUID,
        stage: TelemetryStage,
        durationMilliseconds: Int? = nil,
        count: Int? = nil,
        requestByteCount: Int? = nil,
        responseByteCount: Int? = nil,
        promptVersion: String? = nil,
        operatingSystemVersion: String? = nil,
        providerIdentifier: String? = nil,
        modelIdentifier: String? = nil,
        pendingIdentifier: UUID? = nil,
        changeIdentifier: UUID? = nil,
        replayed: Bool? = nil,
        outcome: String? = nil
    ) {
        self.sequence = sequence
        self.correlationIdentifier = correlationIdentifier
        self.stage = stage
        self.durationMilliseconds = durationMilliseconds
        self.count = count
        self.requestByteCount = requestByteCount
        self.responseByteCount = responseByteCount
        self.promptVersion = promptVersion
        self.operatingSystemVersion = operatingSystemVersion
        self.providerIdentifier = providerIdentifier
        self.modelIdentifier = modelIdentifier
        self.pendingIdentifier = pendingIdentifier
        self.changeIdentifier = changeIdentifier
        self.replayed = replayed
        self.outcome = outcome
    }
}

public enum TraceAssemblyFailure: Error, Sendable, Equatable {
    case mixedCorrelationIdentifiers
    case empty
}

public struct StitchedAgentTrace: Sendable, Equatable {
    public static let deliberatelyAbsentFields = [
        "noteText", "promptText", "toolBody", "userIdentity", "credential", "requestSummary",
    ]

    public let correlationIdentifier: UUID
    public let events: [AgentTelemetryEvent]

    public init(events: [AgentTelemetryEvent]) throws {
        guard let correlationIdentifier = events.first?.correlationIdentifier else {
            throw TraceAssemblyFailure.empty
        }
        guard events.allSatisfy({ $0.correlationIdentifier == correlationIdentifier }) else {
            throw TraceAssemblyFailure.mixedCorrelationIdentifiers
        }
        self.correlationIdentifier = correlationIdentifier
        self.events = events.sorted { $0.sequence < $1.sequence }
    }

    public func rendered() -> String {
        events.map { event in
            var fields = ["stage=\(event.stage.rawValue)"]
            if let value = event.durationMilliseconds { fields.append("duration-ms=\(value)") }
            if let value = event.count { fields.append("count=\(value)") }
            if let value = event.requestByteCount { fields.append("request-bytes=\(value)") }
            if let value = event.responseByteCount { fields.append("response-bytes=\(value)") }
            if let value = event.promptVersion { fields.append("prompt=\(value)") }
            if let value = event.operatingSystemVersion { fields.append("os=\(value)") }
            if let value = event.providerIdentifier { fields.append("provider=\(value)") }
            if let value = event.modelIdentifier { fields.append("model=\(value)") }
            if let value = event.pendingIdentifier { fields.append("pending=\(value)") }
            if let value = event.changeIdentifier { fields.append("change=\(value)") }
            if let value = event.replayed { fields.append("replayed=\(value)") }
            if let value = event.outcome { fields.append("outcome=\(value)") }
            return "\(event.sequence) correlation=\(event.correlationIdentifier) " + fields.joined(separator: " ")
        }.joined(separator: "\n")
    }
}

public enum ContentFreeTraceFixture {
    public static let correlationIdentifier = UUID(
        uuidString: "77777777-7777-4777-8777-777777777777"
    )!
    public static let pendingIdentifier = UUID(
        uuidString: "88888888-8888-4888-8888-888888888888"
    )!
    public static let changeIdentifier = UUID(
        uuidString: "99999999-9999-4999-8999-999999999999"
    )!

    public static func successfulRequest() throws -> StitchedAgentTrace {
        let record = ModelRunRecord(
            promptVersion: .packingBriefV1,
            operatingSystemVersion: "Version 15.7.4 (Build 24G517)",
            providerIdentifier: "fixture-primary",
            modelIdentifier: "fixture-model-a",
            correlationIdentifier: correlationIdentifier.uuidString.lowercased()
        )
        let change = AppliedChange(
            id: changeIdentifier,
            pendingID: pendingIdentifier,
            idempotencyKey: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            action: .savePackingBrief(.init(
                title: "Kyoto packing brief",
                items: ["Rain shell"],
                sourceNoteIDs: [FieldNotesFixture.kyotoID]
            )),
            replayed: false
        )
        return try make(record: record, change: change, outcome: "change-applied")
    }

    public static func rejectedAnswer() throws -> StitchedAgentTrace {
        let record = ModelRunRecord(
            promptVersion: .packingBriefV1,
            operatingSystemVersion: "Version 15.7.4 (Build 24G517)",
            providerIdentifier: "fixture-primary",
            modelIdentifier: "fixture-model-a",
            correlationIdentifier: correlationIdentifier.uuidString.lowercased()
        )
        return try StitchedAgentTrace(events: [
            .init(sequence: 1, correlationIdentifier: correlationIdentifier, stage: .deviceRequest),
            .init(
                sequence: 2,
                correlationIdentifier: correlationIdentifier,
                stage: .modelCompleted,
                durationMilliseconds: 260,
                promptVersion: record.promptVersion.rawValue,
                operatingSystemVersion: record.operatingSystemVersion,
                providerIdentifier: record.providerIdentifier,
                modelIdentifier: record.modelIdentifier
            ),
            .init(
                sequence: 3,
                correlationIdentifier: correlationIdentifier,
                stage: .deviceStopped,
                durationMilliseconds: 345,
                outcome: "person-rejected-answer"
            ),
        ])
    }

    private static func make(
        record: ModelRunRecord,
        change: AppliedChange,
        outcome: String
    ) throws -> StitchedAgentTrace {
        try StitchedAgentTrace(events: [
            .init(sequence: 1, correlationIdentifier: correlationIdentifier, stage: .deviceRequest),
            .init(
                sequence: 2,
                correlationIdentifier: correlationIdentifier,
                stage: .backendAccepted,
                durationMilliseconds: 18,
                requestByteCount: 284
            ),
            .init(
                sequence: 3,
                correlationIdentifier: correlationIdentifier,
                stage: .modelCompleted,
                durationMilliseconds: 260,
                promptVersion: record.promptVersion.rawValue,
                operatingSystemVersion: record.operatingSystemVersion,
                providerIdentifier: record.providerIdentifier,
                modelIdentifier: record.modelIdentifier
            ),
            .init(
                sequence: 4,
                correlationIdentifier: correlationIdentifier,
                stage: .toolCompleted,
                durationMilliseconds: 8,
                count: 1
            ),
            .init(
                sequence: 5,
                correlationIdentifier: correlationIdentifier,
                stage: .changeApplied,
                pendingIdentifier: change.pendingID,
                changeIdentifier: change.id,
                replayed: change.replayed
            ),
            .init(
                sequence: 6,
                correlationIdentifier: correlationIdentifier,
                stage: .deviceStopped,
                durationMilliseconds: 345,
                responseByteCount: 231,
                outcome: outcome
            ),
        ])
    }
}
