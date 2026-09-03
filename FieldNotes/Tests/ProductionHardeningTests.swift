import FieldNotesAgentLoop
import Foundation
import XCTest
@testable import FieldNotes

final class ProductionHardeningTests: XCTestCase {
    private let harness = FaultInjectionHarness()

    func testBackendUnreachableFallsBackToDeterministicBrief() async {
        let result = await harness.injectNetwork(.backendUnreachable)
        XCTAssertTrue(result.behavedAsExpected)
    }

    func testRevokedCloudConsentBlocksRouteBeforeTransmission() async {
        let result = await harness.injectRevokedConsent()
        XCTAssertTrue(result.behavedAsExpected)
    }

    func testUnavailableModelReturnsDeterministicBrief() async {
        let result = await harness.injectUnavailableModel()
        XCTAssertTrue(result.behavedAsExpected)
    }

    @MainActor
    func testDiskFullPreservesUnsavedDraft() async {
        let result = await harness.injectDiskFull(service: FailingCaptureService())
        XCTAssertTrue(result.behavedAsExpected)
    }

    func testMigrationFailureBlocksLaunchWithoutCreatingEmptyStore() {
        let result = harness.injectMigrationFailure()
        XCTAssertTrue(result.behavedAsExpected)
    }

    func testAirplaneModeDuringRetrievalFallsBackToDeterministicBrief() async {
        let result = await harness.injectNetwork(.airplaneModeDuringRetrieval)
        XCTAssertTrue(result.behavedAsExpected)
    }

    func testLowPowerModeSelectsDeterministicBrief() {
        let result = harness.injectOperatingCondition(
            fault: .lowPowerMode,
            condition: .init(thermalState: .nominal, lowPowerModeEnabled: true)
        )
        XCTAssertTrue(result.behavedAsExpected)
    }

    func testThermalPressureSelectsDeterministicBrief() {
        let result = harness.injectOperatingCondition(
            fault: .thermalPressure,
            condition: .init(thermalState: .serious, lowPowerModeEnabled: false)
        )
        XCTAssertTrue(result.behavedAsExpected)
    }

    func testPrivacyManifestDeclaresNoTrackingAndValidArrays() throws {
        let manifest = try propertyList(named: "PrivacyInfo", pathExtension: "xcprivacy")
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertNotNil(manifest["NSPrivacyCollectedDataTypes"] as? [Any])
        XCTAssertNotNil(manifest["NSPrivacyAccessedAPITypes"] as? [Any])
    }

    func testEntitlementUsesSettledAppGroup() throws {
        let entitlements = try propertyList(named: "FieldNotes", pathExtension: "entitlements")
        XCTAssertEqual(
            entitlements["com.apple.security.application-groups"] as? [String],
            ["group.com.example.FieldNotes"]
        )
    }

    private func propertyList(
        named name: String,
        pathExtension: String
    ) throws -> [String: Any] {
        let fieldNotesDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: fieldNotesDirectory
            .appendingPathComponent(name)
            .appendingPathExtension(pathExtension))
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        )
    }
}

private actor FailingCaptureService: CaptureService {
    func save(_ draft: CaptureDraft) throws {
        throw InjectedDependencyFailure.diskFull
    }
}
