import Foundation
import FieldNotesAgentLoop

public enum EvaluationTier: String, Codable, Sendable, Equatable {
    case product
    case adversarial
}

public enum EvaluationScenario: String, Codable, Sendable, Equatable {
    case brief
    case unavailableFallback
    case writeSuspension
    case voiceCapability
    case securityBoundary
}

public enum ExpectedProperty: String, Codable, Sendable, CaseIterable, Equatable {
    case wellFormedBrief
    case sourcesWereAdmitted
    case usesDeterministicFallback
    case writeRequiresApproval
    case voiceCannotApproveConsequentialAction
    case toolDataRemainsUntrusted
    case derivedMemoryRemainsUntrusted
    case exportRequiresExplicitRelease
    case contentCorrelationIsRejected
}

public struct BriefFixture: Codable, Sendable, Equatable {
    public let title: String
    public let items: [String]
    public let sourceNoteIDs: [UUID]

    public var brief: PackingBrief {
        PackingBrief(title: title, items: items, sourceNoteIDs: sourceNoteIDs)
    }
}

public struct EvaluationCase: Codable, Sendable, Identifiable {
    public let id: String
    public let tier: EvaluationTier
    public let scenario: EvaluationScenario
    public let request: String
    public let admittedSourceNoteIDs: [UUID]
    public let candidate: BriefFixture?
    public let expectedProperties: [ExpectedProperty]
}

public enum EvaluationData {
    public static func goldenCases() throws -> [EvaluationCase] {
        try decode("golden-dataset", as: [EvaluationCase].self)
    }

    public static func humanReviews() throws -> [HumanReviewRecord] {
        try decode("human-review", as: [HumanReviewRecord].self)
    }

    private static func decode<Value: Decodable>(_ name: String, as type: Value.Type) throws -> Value {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }
}
