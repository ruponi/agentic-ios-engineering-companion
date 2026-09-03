import Chapter29Evaluation
import Foundation

@main
struct EvaluationRunnerCommand {
    static func main() async throws {
        let cases = try EvaluationData.goldenCases()
        let run = try await GoldenDatasetRunner.run(cases)
        let reviews = try EvaluationData.humanReviews()
        let agreement = ReviewerAgreement.measure(reviews)
        let cell = EvaluationMatrix.verifiedFixtureCell()

        print("dataset=\(run.caseCount) passed=\(run.passed)")
        print("human-agreement=\(agreement.agreed)/\(agreement.total)")
        print("judge-approved=\(JudgeValidator.mayReplaceFirstReviewer(reviews))")
        print("matrix=\(cell.promptVersion)|\(cell.modelRoute)|\(cell.operatingSystem)|\(cell.localeIdentifier)")
    }
}
