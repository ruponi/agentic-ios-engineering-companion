import FieldNotesAgentLoop
import Foundation

enum InjectedReleaseFault: String, CaseIterable, Sendable {
    case backendUnreachable
    case cloudConsentRevoked
    case modelUnavailable
    case diskFull
    case migrationFailure
    case airplaneModeDuringRetrieval
    case lowPowerMode
    case thermalPressure
}

enum ReleaseObservable: String, Sendable, Equatable {
    case modelRoute
    case deterministicBrief
    case draftPreserved
    case cloudRouteBlocked
    case launchBlockedWithoutEmptyStore
}

struct FaultObservation: Sendable, Equatable {
    let fault: InjectedReleaseFault
    let expected: ReleaseObservable
    let actual: ReleaseObservable

    var behavedAsExpected: Bool { expected == actual }
}

enum InjectedDependencyFailure: Error, Sendable {
    case unreachable
    case offline
    case diskFull
    case migrationRejected
}

struct DegradedPackingCoordinator: Sendable {
    let remoteBrief: @Sendable () async throws -> PackingBrief
    let fallback: DeterministicPackingWorkflow

    func makeBrief(query: String) async -> ReleaseObservable {
        do {
            _ = try await remoteBrief()
            return .modelRoute
        } catch {
            _ = try? await fallback.makeBrief(query: query)
            return .deterministicBrief
        }
    }
}

enum ReleaseRoutePolicy {
    static func observable(for condition: DeviceOperatingCondition) -> ReleaseObservable {
        if condition.lowPowerModeEnabled ||
            condition.thermalState == .serious ||
            condition.thermalState == .critical {
            return .deterministicBrief
        }
        return .modelRoute
    }
}

struct FaultInjectionHarness: Sendable {
    func injectNetwork(_ fault: InjectedReleaseFault) async -> FaultObservation {
        let failure: InjectedDependencyFailure = fault == .backendUnreachable
            ? .unreachable
            : .offline
        let coordinator = DegradedPackingCoordinator(
            remoteBrief: { throw failure },
            fallback: DeterministicPackingWorkflow(
                searchTool: FieldNotesFixture.searchTool()
            )
        )
        return FaultObservation(
            fault: fault,
            expected: .deterministicBrief,
            actual: await coordinator.makeBrief(query: "Kyoto")
        )
    }

    func injectUnavailableModel() async -> FaultObservation {
        let result = await PackingFeature(
            readiness: .frameworkNotPresent,
            model: UnavailableModel(),
            searchTool: FieldNotesFixture.searchTool()
        ).makePackingBrief(request: FieldNotesFixture.request, query: "Kyoto")
        let actual: ReleaseObservable
        if case .deterministicFallback = result.placement {
            actual = .deterministicBrief
        } else {
            actual = .cloudRouteBlocked
        }
        return FaultObservation(
            fault: .modelUnavailable,
            expected: .deterministicBrief,
            actual: actual
        )
    }

    func injectRevokedConsent() async -> FaultObservation {
        let cloudLedger = CloudConsentLedger()
        let memoryLedger = MemoryConsentLedger()
        let cloudGrant = await cloudLedger.grant(.packingBrief)
        let memoryGrant = await memoryLedger.grant()
        await cloudLedger.revoke(cloudGrant)
        let permissions = await AgentPermissionSet.validated(
            cloudGrant: cloudGrant,
            cloudLedger: cloudLedger,
            memoryGrant: memoryGrant,
            memoryLedger: memoryLedger
        )
        return FaultObservation(
            fault: .cloudConsentRevoked,
            expected: .cloudRouteBlocked,
            actual: permissions.allowsCloudInference
                ? .deterministicBrief
                : .cloudRouteBlocked
        )
    }

    @MainActor
    func injectDiskFull(service: any CaptureService) async -> FaultObservation {
        let model = CaptureModel(service: service)
        model.text = "Kyoto packing\nRain shell"
        _ = await model.save()
        return FaultObservation(
            fault: .diskFull,
            expected: .draftPreserved,
            actual: model.text.isEmpty ? .deterministicBrief : .draftPreserved
        )
    }

    func injectMigrationFailure() -> FaultObservation {
        let result = FieldNotesPersistence.open {
            throw InjectedDependencyFailure.migrationRejected
        }
        let actual: ReleaseObservable
        switch result {
        case .success:
            actual = .deterministicBrief
        case .failure:
            actual = .launchBlockedWithoutEmptyStore
        }
        return FaultObservation(
            fault: .migrationFailure,
            expected: .launchBlockedWithoutEmptyStore,
            actual: actual
        )
    }

    func injectOperatingCondition(
        fault: InjectedReleaseFault,
        condition: DeviceOperatingCondition
    ) -> FaultObservation {
        FaultObservation(
            fault: fault,
            expected: .deterministicBrief,
            actual: ReleaseRoutePolicy.observable(for: condition)
        )
    }
}
