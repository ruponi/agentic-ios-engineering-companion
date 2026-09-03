import Foundation
import FieldNotesAgentLoop

public enum AgentFeatureFlag: String, Sendable, Equatable {
    case enabled
    case disabled
}

public enum ReleaseRoute: String, Sendable, Equatable {
    case model
    case deterministicBrief
}

public struct ReleaseRouteResult: Sendable, Equatable {
    public let route: ReleaseRoute
    public let brief: PackingBrief?

    public init(route: ReleaseRoute, brief: PackingBrief?) {
        self.route = route
        self.brief = brief
    }
}

public struct PackingBriefReleaseRouter: Sendable {
    public let flag: AgentFeatureFlag

    public init(flag: AgentFeatureFlag) {
        self.flag = flag
    }

    public func makeBrief() async -> ReleaseRouteResult {
        if flag == .disabled {
            let brief = try? await DeterministicPackingWorkflow(
                searchTool: FieldNotesFixture.searchTool()
            ).makeBrief(query: "Kyoto")
            return ReleaseRouteResult(route: .deterministicBrief, brief: brief)
        }

        let result = await PackingFeature(
            readiness: .available,
            model: FieldNotesFixture.successfulModel(),
            searchTool: FieldNotesFixture.searchTool()
        ).makePackingBrief(request: FieldNotesFixture.request, query: "Kyoto")
        return ReleaseRouteResult(route: .model, brief: result.brief)
    }
}

public enum PromptSupportState: String, Sendable, Equatable {
    case supported
    case deprecationCandidate
    case retired
}

public struct PromptReleasePlan: Sendable, Equatable {
    public let activePrompt: PromptVersion
    public let rollbackPrompt: PromptVersion
    public let operatingSystemVersion: String
    public let v1Support: PromptSupportState

    public init(
        activePrompt: PromptVersion,
        rollbackPrompt: PromptVersion,
        operatingSystemVersion: String,
        v1Support: PromptSupportState
    ) {
        self.activePrompt = activePrompt
        self.rollbackPrompt = rollbackPrompt
        self.operatingSystemVersion = operatingSystemVersion
        self.v1Support = v1Support
    }

    public func rollingBackPrompt() -> Self {
        Self(
            activePrompt: rollbackPrompt,
            rollbackPrompt: rollbackPrompt,
            operatingSystemVersion: operatingSystemVersion,
            v1Support: v1Support
        )
    }

    public func mayRetireV1(
        successorPassesGoldenDataset: Bool,
        filledLiveMatrixCells: Int,
        offRouteVerified: Bool
    ) -> Bool {
        successorPassesGoldenDataset && filledLiveMatrixCells > 0 && offRouteVerified
    }
}
