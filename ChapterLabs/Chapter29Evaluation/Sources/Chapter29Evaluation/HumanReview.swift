import Foundation

public struct HumanReviewRecord: Codable, Sendable, Equatable {
    public let candidateID: String
    public let reviewerAScore: Int
    public let reviewerBScore: Int
    public let judgePass: Bool

    public init(candidateID: String, reviewerAScore: Int, reviewerBScore: Int, judgePass: Bool) {
        self.candidateID = candidateID
        self.reviewerAScore = reviewerAScore
        self.reviewerBScore = reviewerBScore
        self.judgePass = judgePass
    }
}

public enum HumanUsefulnessCriterion {
    public static let passingScore = 3

    public static func passes(score: Int) -> Bool {
        score >= passingScore
    }
}

public struct AgreementReport: Sendable, Equatable {
    public let agreed: Int
    public let total: Int

    public init(agreed: Int, total: Int) {
        self.agreed = agreed
        self.total = total
    }

    public var rate: Double {
        total == 0 ? 0 : Double(agreed) / Double(total)
    }
}

public enum ReviewerAgreement {
    public static func measure(_ reviews: [HumanReviewRecord]) -> AgreementReport {
        let agreed = reviews.count {
            HumanUsefulnessCriterion.passes(score: $0.reviewerAScore)
                == HumanUsefulnessCriterion.passes(score: $0.reviewerBScore)
        }
        return AgreementReport(agreed: agreed, total: reviews.count)
    }
}

public enum JudgeValidator {
    public static let requiredAgreement = 0.90

    public static func agreement(with reviews: [HumanReviewRecord]) -> AgreementReport {
        let agreed = reviews.count {
            $0.judgePass == HumanUsefulnessCriterion.passes(score: $0.reviewerAScore)
        }
        return AgreementReport(agreed: agreed, total: reviews.count)
    }

    public static func mayReplaceFirstReviewer(_ reviews: [HumanReviewRecord]) -> Bool {
        agreement(with: reviews).rate >= requiredAgreement
    }
}
