import Chapter29Evaluation
import FieldNotesAgentLoop
import Foundation
import Testing

@Suite("Chapter 29 product-agent evaluation")
struct Chapter29EvaluationTests {
    @Test("golden dataset stores ten property-based cases")
    func goldenDatasetStoresTenPropertyBasedCases() throws {
        let cases = try EvaluationData.goldenCases()

        #expect(cases.count == 10)
        #expect(cases.count { $0.tier == .adversarial } == 6)
        #expect(cases.allSatisfy { !$0.expectedProperties.isEmpty })
    }

    @Test("ten-case deterministic dataset passes")
    func tenCaseDeterministicDatasetPasses() async throws {
        let run = try await GoldenDatasetRunner.run(EvaluationData.goldenCases())

        #expect(run.caseCount == 10)
        #expect(run.passed)
    }

    @Test("groundedness grader rejects an unobserved UUID")
    func groundednessGraderRejectsUnobservedUUID() {
        let unobserved = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let brief = PackingBrief(
            title: "Kyoto packing brief",
            items: ["Rain shell"],
            sourceNoteIDs: [unobserved]
        )

        let result = GroundednessGrader.grade(
            brief,
            admittedSourceIDs: [FieldNotesFixture.kyotoID]
        )
        #expect(!result.passed)
    }

    @Test("structural graders pass a useless brief but the human criterion rejects it")
    func structuralGradersPassUselessBriefButHumanRejects() {
        let brief = PackingBrief(
            title: "Kyoto packing brief",
            items: ["Smile", "Stay curious"],
            sourceNoteIDs: [FieldNotesFixture.kyotoID]
        )

        #expect(BriefStructureGrader.grade(brief).passed)
        #expect(GroundednessGrader.grade(
            brief,
            admittedSourceIDs: [FieldNotesFixture.kyotoID]
        ).passed)
        #expect(!HumanUsefulnessCriterion.passes(score: 1))
    }

    @Test("unavailable model selects a deterministic fallback")
    func unavailableModelSelectsDeterministicFallback() async {
        let result = await PackingFeature(
            readiness: .frameworkNotPresent,
            model: UnavailableModel(),
            searchTool: FieldNotesFixture.searchTool()
        ).makePackingBrief(request: FieldNotesFixture.request, query: "Kyoto")

        #expect(FallbackGrader.grade(result).passed)
    }

    @Test("write proposal suspends for approval")
    func writeProposalSuspendsForApproval() async throws {
        let cases = try EvaluationData.goldenCases().filter { $0.scenario == .writeSuspension }
        let run = try await GoldenDatasetRunner.run(cases)

        #expect(run.passed)
    }

    @Test("voice cannot approve a consequential action")
    func voiceCannotApproveConsequentialAction() async throws {
        let cases = try EvaluationData.goldenCases().filter { $0.scenario == .voiceCapability }
        let run = try await GoldenDatasetRunner.run(cases)

        #expect(run.passed)
    }

    @Test("reviewer disagreement is measured and blocks judge substitution")
    func reviewerDisagreementIsMeasuredAndBlocksJudgeSubstitution() throws {
        let reviews = try EvaluationData.humanReviews()
        let humanAgreement = ReviewerAgreement.measure(reviews)
        let judgeAgreement = JudgeValidator.agreement(with: reviews)

        #expect(humanAgreement == AgreementReport(agreed: 4, total: 5))
        #expect(judgeAgreement == AgreementReport(agreed: 4, total: 5))
        #expect(!JudgeValidator.mayReplaceFirstReviewer(reviews))
    }

    @Test("matrix cell records locale beside model-run evidence")
    func matrixCellRecordsLocaleBesideModelRunEvidence() {
        let cell = EvaluationMatrix.verifiedFixtureCell()

        #expect(cell.promptVersion == "packing-brief/v1")
        #expect(cell.modelRoute == "scripted-fixture")
        #expect(cell.localeIdentifier == "en_US_POSIX")
        #expect(cell.status == .filled)
    }
}
