import Foundation

public enum ModelReadiness: String, Sendable, Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case frameworkNotPresent
}

public enum ModelReadinessFailure: Error, Sendable, Equatable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case frameworkNotPresent
}

public struct AvailabilityGatedModel: AgentModel, Sendable {
    private let readiness: ModelReadiness
    private let model: any AgentModel

    public init(readiness: ModelReadiness, model: any AgentModel) {
        self.readiness = readiness
        self.model = model
    }

    public func respond(to context: AgentContext) async throws -> AgentProposal {
        switch readiness {
        case .available:
            try await model.respond(to: context)
        case .deviceNotEligible:
            throw ModelReadinessFailure.deviceNotEligible
        case .appleIntelligenceNotEnabled:
            throw ModelReadinessFailure.appleIntelligenceNotEnabled
        case .modelNotReady:
            throw ModelReadinessFailure.modelNotReady
        case .frameworkNotPresent:
            throw ModelReadinessFailure.frameworkNotPresent
        }
    }
}

/// Floor-safe stand-in installed below the Foundation Models availability wall.
/// `AvailabilityGatedModel` refuses before this is reached; it exists so the
/// production composition can name a model on a system without the framework.
public struct UnavailableModel: AgentModel, Sendable {
    public init() {}

    public func respond(to context: AgentContext) async throws -> AgentProposal {
        throw ModelReadinessFailure.frameworkNotPresent
    }
}

public enum PackingPlacement: Sendable, Equatable, CustomStringConvertible {
    case onDevice
    case deterministicFallback(AgentLoopFailure)
    case failed(AgentLoopFailure)
    case cancelled
    case turnLimitReached

    public var description: String {
        switch self {
        case .onDevice:
            "on-device"
        case .deterministicFallback(let failure):
            "deterministic-fallback reason=\(failure)"
        case .failed(let failure):
            "failed reason=\(failure)"
        case .cancelled:
            "cancelled"
        case .turnLimitReached:
            "turn-limit-reached"
        }
    }
}

public struct PackingPlacementResult: Sendable, Equatable {
    public let placement: PackingPlacement
    public let brief: PackingBrief?

    public init(placement: PackingPlacement, brief: PackingBrief?) {
        self.placement = placement
        self.brief = brief
    }
}

public struct PackingFeature: Sendable {
    private let readiness: ModelReadiness
    private let model: any AgentModel
    private let searchTool: any ReadOnlyNoteSearching

    public init(
        readiness: ModelReadiness,
        model: any AgentModel,
        searchTool: any ReadOnlyNoteSearching
    ) {
        self.readiness = readiness
        self.model = model
        self.searchTool = searchTool
    }

    public func makePackingBrief(request: String, query: String) async -> PackingPlacementResult {
        let gatedModel = AvailabilityGatedModel(readiness: readiness, model: model)
        let outcome = await AgentLoop(model: gatedModel, searchTool: searchTool).run(request: request)

        switch outcome {
        case .succeeded(let brief, _):
            return PackingPlacementResult(placement: .onDevice, brief: brief)
        case .failed(let failure, _) where failure.isAvailabilityFailure:
            do {
                let fallback = try await DeterministicPackingWorkflow(searchTool: searchTool)
                    .makeBrief(query: query)
                return PackingPlacementResult(
                    placement: .deterministicFallback(failure),
                    brief: fallback
                )
            } catch {
                return PackingPlacementResult(
                    placement: .failed(.toolFailed(String(describing: error))),
                    brief: nil
                )
            }
        case .failed(let failure, _):
            return PackingPlacementResult(placement: .failed(failure), brief: nil)
        case .cancelled:
            return PackingPlacementResult(placement: .cancelled, brief: nil)
        case .turnLimitReached:
            return PackingPlacementResult(placement: .turnLimitReached, brief: nil)
        case .suspended, .changeApplied, .declined:
            return PackingPlacementResult(
                placement: .failed(.toolFailed("unexpected write outcome in read-only feature")),
                brief: nil
            )
        }
    }
}

private extension AgentLoopFailure {
    var isAvailabilityFailure: Bool {
        switch self {
        case .modelUnavailable, .modelIneligible, .modelNotReady:
            true
        default:
            false
        }
    }
}
