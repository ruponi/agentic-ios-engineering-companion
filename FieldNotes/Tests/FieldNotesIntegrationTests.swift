import FieldNotesAgentLoop
import SwiftData
import XCTest
@testable import FieldNotes

final class FieldNotesIntegrationTests: XCTestCase {
    func testPackagePersonalContextRecordPersistsWithoutShadowType() async throws {
        let container = try makeContainer()
        let ledger = MemoryConsentLedger()
        let grant = await ledger.grant()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let record = PersonalContextRecord(
            value: "Prefers a rain shell",
            sourceNoteID: UUID(),
            derivedAt: now,
            derivationVersion: "preference/v1",
            expiresAt: now.addingTimeInterval(3_600)
        )

        let store = SwiftDataPersonalContextStore(modelContainer: container)
        try await store.regenerate([record], grant: grant, ledger: ledger, now: now)

        let persisted = try await store.records(
            grant: grant,
            ledger: ledger,
            now: now
        )
        XCTAssertEqual(persisted, [record])
    }

    func testRealNoteBodyFitsLoopToolResultBudget() async throws {
        let container = try makeContainer()
        let noteStore = SwiftDataNoteStore(modelContainer: container)
        try await noteStore.save(CaptureDraft(
            text: "Kyoto packing\n" + String(repeating: "rain shell and notebook ", count: 300)
        ))
        let search = SwiftDataAgentSearchTool(modelContainer: container)
        let documents = try await search.search(query: "Kyoto")
        let envelope = ToolResultEnvelope(
            sourceTool: FieldNotesSearchTool.name,
            data: documents
        )
        let encoded = String(decoding: try JSONEncoder().encode(envelope), as: UTF8.self)

        XCTAssertFalse(documents.isEmpty)
        XCTAssertLessThanOrEqual(encoded.count, 2_000)
        XCTAssertLessThanOrEqual(documents[0].body.count, 320)
    }

    func testCloudAndMemoryConsentsStayIndependent() async {
        let cloudLedger = CloudConsentLedger()
        let memoryLedger = MemoryConsentLedger()
        let cloud = await cloudLedger.grant(.packingBrief)
        let memory = await memoryLedger.grant()

        XCTAssertEqual(
            AgentPermissionSet.resolve(cloudGrant: nil, memoryGrant: nil),
            .init(allowsCloudInference: false, allowsDerivedMemory: false)
        )
        XCTAssertEqual(
            AgentPermissionSet.resolve(cloudGrant: cloud, memoryGrant: nil),
            .init(allowsCloudInference: true, allowsDerivedMemory: false)
        )
        XCTAssertEqual(
            AgentPermissionSet.resolve(cloudGrant: nil, memoryGrant: memory),
            .init(allowsCloudInference: false, allowsDerivedMemory: true)
        )
        XCTAssertEqual(
            AgentPermissionSet.resolve(cloudGrant: cloud, memoryGrant: memory),
            .init(allowsCloudInference: true, allowsDerivedMemory: true)
        )
    }

    func testAmendmentReplacesSuspendedPendingBeforeResume() async throws {
        let store = VersionedNoteStore()
        let loop = try makeWriteLoop(store: store)
        guard case .suspended(let suspended) = await loop.run(request: FieldNotesFixture.request) else {
            return XCTFail("Expected suspension")
        }
        let amendment = PendingActionAmendment(original: suspended.pending)
            .replacingAction(with: .savePackingBrief(.init(
                title: "Amended field kit",
                items: ["Rain shell"],
                sourceNoteIDs: [FieldNotesFixture.kyotoID]
            )))
        let replacement = try suspended.replacingPending(with: amendment)
        let approval = try amendment.approve(pendingID: amendment.pending.id)

        guard case .changeApplied(let change, _) = await loop.resume(replacement, with: approval) else {
            return XCTFail("Expected amended action to apply")
        }
        XCTAssertEqual(change.pendingID, amendment.pending.id)
        XCTAssertNotEqual(change.pendingID, suspended.pending.id)
    }

    func testAppTargetJourneyStitchesCaptureSearchApprovalAndAudit() async throws {
        let evidence = try await IntegratedAgentJourney(modelContainer: makeContainer()).run(
            noteText: "Kyoto packing\nRain shell, rail pass, and notebook.",
            route: .onDevice,
            permissions: .init(allowsCloudInference: false, allowsDerivedMemory: false)
        )

        XCTAssertEqual(evidence.route, .onDevice)
        XCTAssertEqual(evidence.localSearchCount, 1)
        XCTAssertEqual(evidence.auditRecord.changes.count, 1)
        XCTAssertEqual(evidence.auditRecord.modelRuns.count, 1)
        XCTAssertEqual(evidence.signpostStages, ["request", "change"])
        XCTAssertTrue(evidence.trace.contains { $0.detail.contains("searchNotes") })
        XCTAssertTrue(evidence.trace.contains { $0.detail.contains("change-applied") })
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: FieldNotesSchemaV3.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeWriteLoop(store: VersionedNoteStore) throws -> AgentLoop {
        let arguments = SavePackingBriefArguments(
            title: "Kyoto packing brief",
            items: ["Rain shell", "Rail pass", "Notebook"],
            sourceNoteIDs: [FieldNotesFixture.kyotoID]
        )
        return AgentLoop(
            model: ScriptedModel([
                .toolCall(.init(
                    id: "integration-search",
                    name: FieldNotesSearchTool.name,
                    argumentsJSON: FieldNotesFixture.kyotoArguments
                )),
                .toolCall(.init(
                    id: "integration-save",
                    name: SavePackingBriefTool.name,
                    argumentsJSON: String(
                        decoding: try JSONEncoder().encode(arguments),
                        as: UTF8.self
                    )
                ))
            ]),
            searchTool: FieldNotesFixture.searchTool(),
            saveTool: SavePackingBriefTool(store: store)
        )
    }
}
