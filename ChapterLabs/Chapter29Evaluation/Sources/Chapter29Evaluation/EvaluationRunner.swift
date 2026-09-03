import Foundation
import FieldNotesAgentLoop

public struct DatasetRun: Sendable {
    public let caseCount: Int
    public let results: [String: [GraderResult]]

    public var passed: Bool {
        results.values.flatMap { $0 }.allSatisfy(\.passed)
    }
}

public enum GoldenDatasetRunner {
    public static func run(_ cases: [EvaluationCase]) async throws -> DatasetRun {
        var allResults: [String: [GraderResult]] = [:]
        for evaluationCase in cases {
            allResults[evaluationCase.id] = try await evaluate(evaluationCase)
        }
        return DatasetRun(caseCount: cases.count, results: allResults)
    }

    private static func evaluate(_ evaluationCase: EvaluationCase) async throws -> [GraderResult] {
        switch evaluationCase.scenario {
        case .brief:
            guard let brief = evaluationCase.candidate?.brief else { return [] }
            return evaluationCase.expectedProperties.map { property in
                switch property {
                case .wellFormedBrief:
                    BriefStructureGrader.grade(brief)
                case .sourcesWereAdmitted:
                    GroundednessGrader.grade(
                        brief,
                        admittedSourceIDs: Set(evaluationCase.admittedSourceNoteIDs)
                    )
                default:
                    GraderResult(property: property, passed: false, evidence: "wrong-scenario")
                }
            }

        case .unavailableFallback:
            let result = await PackingFeature(
                readiness: .frameworkNotPresent,
                model: UnavailableModel(),
                searchTool: FieldNotesFixture.searchTool()
            ).makePackingBrief(request: evaluationCase.request, query: "Kyoto")
            return [FallbackGrader.grade(result)]

        case .writeSuspension:
            let arguments = SavePackingBriefArguments(
                title: "Kyoto packing brief",
                items: ["Rain shell"],
                sourceNoteIDs: [FieldNotesFixture.kyotoID]
            )
            let argumentsJSON = String(decoding: try JSONEncoder().encode(arguments), as: UTF8.self)
            let loop = AgentLoop(
                model: ScriptedModel([
                    .toolCall(ToolCall(
                        id: "search-1",
                        name: FieldNotesSearchTool.name,
                        argumentsJSON: FieldNotesFixture.kyotoArguments
                    )),
                    .toolCall(ToolCall(
                        id: "write-1",
                        name: SavePackingBriefTool.name,
                        argumentsJSON: argumentsJSON
                    )),
                ]),
                searchTool: FieldNotesFixture.searchTool(),
                saveTool: SavePackingBriefTool(store: VersionedNoteStore())
            )
            return [ApprovalSuspensionGrader.grade(await loop.run(request: evaluationCase.request))]

        case .voiceCapability:
            let pending = PendingAction(
                callID: "voice-delete",
                effect: .consequential,
                action: .deleteNote(.init(noteID: FieldNotesFixture.kyotoID))
            )
            let session = VoiceApprovalSession(pending: pending)
            do {
                _ = try await session.beginReadback()
                return [VoiceCapabilityGrader.grade(nil)]
            } catch let failure as VoiceApprovalFailure {
                return [VoiceCapabilityGrader.grade(failure)]
            }

        case .securityBoundary:
            return evaluationCase.expectedProperties.map {
                SecurityBoundaryGrader.grade(property: $0, hostileText: evaluationCase.request)
            }
        }
    }
}
