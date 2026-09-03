import Chapter30Observability
import FieldNotesAgentLoop
import Foundation
import Testing

@Suite("Chapter 30 content-free observability")
struct Chapter30ObservabilityTests {
    @Test("stitched trace rejects mismatched correlation identifiers")
    func stitchedTraceRejectsMismatchedCorrelationIdentifiers() {
        let first = UUID()
        let second = UUID()
        #expect(throws: TraceAssemblyFailure.mixedCorrelationIdentifiers) {
            try StitchedAgentTrace(events: [
                .init(sequence: 1, correlationIdentifier: first, stage: .deviceRequest),
                .init(sequence: 2, correlationIdentifier: second, stage: .backendAccepted),
            ])
        }
    }

    @Test("stitched request carries evidence and no content fields")
    func stitchedRequestCarriesEvidenceAndNoContentFields() throws {
        let trace = try ContentFreeTraceFixture.successfulRequest()
        let encoded = try JSONEncoder().encode(trace.events)
        let text = String(decoding: encoded, as: UTF8.self)

        #expect(trace.events.count == 6)
        #expect(Set(trace.events.map(\.correlationIdentifier)).count == 1)
        #expect(!text.contains("Rain shell"))
        #expect(!text.contains("Prepare a short packing brief"))
    }

    @Test("content-free trace cannot explain a rejected answer")
    func contentFreeTraceCannotExplainRejectedAnswer() throws {
        let trace = try ContentFreeTraceFixture.rejectedAnswer()

        #expect(trace.events.last?.outcome == "person-rejected-answer")
        #expect(trace.rendered().contains("why=") == false)
        #expect(StitchedAgentTrace.deliberatelyAbsentFields.contains("requestSummary"))
    }

    @Test("canonical request stays within all four loop budgets")
    func canonicalRequestStaysWithinAllFourLoopBudgets() async throws {
        let observation = try await AgentBudgetObserver.canonicalRequest()

        #expect(observation.modelTurns == 2)
        #expect(observation.maximumRetainedMessages == 3)
        #expect(observation.toolResultCharacters > 0)
        #expect(observation.fits())
    }

    @Test("budget observer rejects a tool result above two thousand characters")
    func budgetObserverRejectsToolResultAboveTwoThousandCharacters() {
        let observation = AgentBudgetObservation(
            modelTurns: 2,
            maximumRetainedMessages: 3,
            toolResultCharacters: 2_001,
            recoverableToolFailures: 0
        )

        #expect(!observation.fits())
    }

    @Test("responsiveness separates first output from total time")
    func responsivenessSeparatesFirstOutputFromTotalTime() async throws {
        let measurement = try await PerceivedResponsivenessProbe.run()

        #expect(measurement.timeToFirstOutputMilliseconds >= 15)
        #expect(measurement.totalMilliseconds > measurement.timeToFirstOutputMilliseconds)
        #expect(measurement.totalMilliseconds < 500)
    }

    @Test("disabled agent flag returns the existing deterministic brief")
    func disabledAgentFlagReturnsExistingDeterministicBrief() async {
        let result = await PackingBriefReleaseRouter(flag: .disabled).makeBrief()

        #expect(result.route == .deterministicBrief)
        #expect(result.brief?.sourceNoteIDs == [FieldNotesFixture.kyotoID])
    }

    @Test("prompt rollback cannot roll back the operating system model")
    func promptRollbackCannotRollBackOperatingSystemModel() {
        let plan = PromptReleasePlan(
            activePrompt: .init(rawValue: "packing-brief/v2"),
            rollbackPrompt: .packingBriefV1,
            operatingSystemVersion: "26.1",
            v1Support: .supported
        )

        let rollback = plan.rollingBackPrompt()
        #expect(rollback.activePrompt == .packingBriefV1)
        #expect(rollback.operatingSystemVersion == "26.1")
    }

    @Test("version one retirement requires successor live and fallback evidence")
    func versionOneRetirementRequiresSuccessorLiveAndFallbackEvidence() {
        let plan = PromptReleasePlan(
            activePrompt: .init(rawValue: "packing-brief/v2"),
            rollbackPrompt: .packingBriefV1,
            operatingSystemVersion: "26.1",
            v1Support: .deprecationCandidate
        )

        #expect(!plan.mayRetireV1(
            successorPassesGoldenDataset: true,
            filledLiveMatrixCells: 0,
            offRouteVerified: true
        ))
        #expect(plan.mayRetireV1(
            successorPassesGoldenDataset: true,
            filledLiveMatrixCells: 1,
            offRouteVerified: true
        ))
    }
}
