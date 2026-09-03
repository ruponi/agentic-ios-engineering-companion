import BeyondOneAgent
import FieldNotesAgentLoop
import Foundation
import Testing

@Suite("A specialist remains inside one referee")
struct BeyondOneAgentTests {
    @Test("specialist result uses the existing untrusted tool envelope")
    func specialistUsesToolEnvelope() async throws {
        let budget = TreeTurnBudget(total: 4, maximumDepth: 1)
        let tool = RegisteredReadTool(RoutePlannerAgentTool(
            planner: BudgetedRoutePlanner(budget: budget)
        ))
        let output = try await tool.call(argumentsJSON: argumentsJSON(destination: "Kyoto"))
        let envelope = try JSONDecoder().decode(
            ToolResultEnvelope<SpecialistRoute>.self,
            from: Data(output.utf8)
        )

        #expect(envelope.boundary == "untrusted-tool-data")
        #expect(envelope.sourceTool == "planRoute")
        #expect(envelope.data.childTurns == 2)
    }

    @Test("specialist output cannot admit provenance to the outer loop")
    func outerProvenanceRuleIsUnchanged() async {
        let budget = TreeTurnBudget(total: 4, maximumDepth: 1)
        let model = ScriptedModel([
            .toolCall(ToolCall(
                id: "specialist-1",
                name: "planRoute",
                argumentsJSON: argumentsJSON(destination: "Kyoto")
            )),
            .final(PackingBrief(
                title: "Unadmitted",
                items: ["Rain shell"],
                sourceNoteIDs: [FieldNotesFixture.kyotoID]
            ))
        ])
        let outcome = await AgentLoop(
            model: model,
            searchTool: FieldNotesFixture.searchTool(),
            registeredReadTools: [RegisteredReadTool(RoutePlannerAgentTool(
                planner: BudgetedRoutePlanner(budget: budget)
            ))]
        ).run(request: FieldNotesFixture.request)

        guard case .failed(.invalidFinalProvenance, _) = outcome else {
            Issue.record("Expected the unchanged outer provenance rejection")
            return
        }
    }

    @Test("registered specialist does not change the host approval path")
    func approvalPathIsUnchanged() async {
        let budget = TreeTurnBudget(total: 6, maximumDepth: 1)
        let saveArguments = SavePackingBriefArguments(
            title: "Kyoto packing brief",
            items: ["Rain shell"],
            sourceNoteIDs: [FieldNotesFixture.kyotoID]
        )
        let model = ScriptedModel([
            .toolCall(.init(id: "specialist-1", name: "planRoute", argumentsJSON: argumentsJSON(destination: "Kyoto"))),
            .toolCall(.init(id: "search-1", name: "searchNotes", argumentsJSON: FieldNotesFixture.kyotoArguments)),
            .toolCall(.init(id: "save-1", name: "savePackingBrief", argumentsJSON: encode(saveArguments)))
        ])
        let store = VersionedNoteStore()
        let outcome = await AgentLoop(
            model: model,
            searchTool: FieldNotesFixture.searchTool(),
            saveTool: SavePackingBriefTool(store: store),
            registeredReadTools: [RegisteredReadTool(RoutePlannerAgentTool(
                planner: BudgetedRoutePlanner(budget: budget)
            ))]
        ).run(request: FieldNotesFixture.request)

        guard case .suspended(let run) = outcome else {
            Issue.record("Expected the existing suspended approval path")
            return
        }
        #expect(run.pending.effect == .reversibleWrite)
        #expect(run.pending.callID == "save-1")
    }

    @Test("outer turn limit is unchanged with a specialist registered")
    func outerTurnLimitIsUnchanged() async {
        let budget = TreeTurnBudget(total: 8, maximumDepth: 1)
        let model = ScriptedModel([
            .toolCall(.init(id: "specialist-1", name: "planRoute", argumentsJSON: argumentsJSON(destination: "Kyoto"))),
            .toolCall(.init(id: "specialist-2", name: "planRoute", argumentsJSON: argumentsJSON(destination: "Osaka")))
        ])
        let outcome = await AgentLoop(
            model: model,
            searchTool: FieldNotesFixture.searchTool(),
            registeredReadTools: [RegisteredReadTool(RoutePlannerAgentTool(
                planner: BudgetedRoutePlanner(budget: budget)
            ))],
            configuration: .init(maxTurns: 2)
        ).run(request: FieldNotesFixture.request)

        guard case .turnLimitReached(let trace) = outcome else {
            Issue.record("Expected the existing turn-limit outcome")
            return
        }
        #expect(trace.last?.description == "STOP turn-limit reached=2")
    }

    @Test("parent and child consumption share one tree budget")
    func treeBudgetChargesBothLevels() async throws {
        let budget = TreeTurnBudget(total: 4, maximumDepth: 1)
        try await budget.charge(turns: 1, atDepth: 0)
        let planner = BudgetedRoutePlanner(budget: budget, childTurns: 2)
        _ = try await planner.route(for: arguments(destination: "Kyoto"))
        let snapshot = await budget.snapshot

        #expect(snapshot.consumed == 3)
        #expect(snapshot.remaining == 1)
        #expect(snapshot.maximumDepth == 1)
    }

    @Test("tree exhaustion stops the outer loop cleanly")
    func treeBudgetStopsCleanly() async {
        let budget = TreeTurnBudget(total: 2, maximumDepth: 1)
        _ = try? await budget.charge(turns: 1, atDepth: 0)
        let model = ScriptedModel([.toolCall(.init(
            id: "specialist-1",
            name: "planRoute",
            argumentsJSON: argumentsJSON(destination: "Kyoto")
        ))])
        let outcome = await AgentLoop(
            model: model,
            searchTool: FieldNotesFixture.searchTool(),
            registeredReadTools: [RegisteredReadTool(RoutePlannerAgentTool(
                planner: BudgetedRoutePlanner(budget: budget, childTurns: 2)
            ))]
        ).run(request: FieldNotesFixture.request)

        guard case .failed(.toolFailed(let reason), let trace) = outcome else {
            Issue.record("Expected a clean failed outcome")
            return
        }
        #expect(reason.contains("treeBudgetExhausted"))
        #expect(trace.last?.description.contains("STOP failed") == true)
    }

    @Test("unusable child output stops instead of consuming another turn")
    func unusableResultStopsCleanly() async {
        let model = ScriptedModel([.toolCall(.init(
            id: "specialist-1",
            name: "planRoute",
            argumentsJSON: argumentsJSON(destination: "Kyoto")
        ))])
        let outcome = await AgentLoop(
            model: model,
            searchTool: FieldNotesFixture.searchTool(),
            registeredReadTools: [RegisteredReadTool(RoutePlannerAgentTool(
                planner: UnusableRoutePlanner()
            ))]
        ).run(request: FieldNotesFixture.request)

        guard case .failed(.toolFailed(let reason), let trace) = outcome else {
            Issue.record("Expected unusable output to stop")
            return
        }
        #expect(reason == "unusableSpecialistResult")
        #expect(trace.filter { $0.stage == "DECIDE" }.count == 1)
    }

    @Test("specialist timeout becomes an outer-loop failure")
    func specialistTimeoutStopsCleanly() async {
        let model = ScriptedModel([.toolCall(.init(
            id: "specialist-1",
            name: "planRoute",
            argumentsJSON: argumentsJSON(destination: "Kyoto")
        ))])
        let outcome = await AgentLoop(
            model: model,
            searchTool: FieldNotesFixture.searchTool(),
            registeredReadTools: [RegisteredReadTool(RoutePlannerAgentTool(
                planner: SlowRoutePlanner()
            ))]
        ).run(request: FieldNotesFixture.request)

        guard case .failed(.toolFailed(let reason), _) = outcome else {
            Issue.record("Expected timeout failure")
            return
        }
        #expect(reason == "timedOut(tool:planRoute)")
    }

    @Test("platform constraints never grant a new write path")
    func platformConstraintsKeepApprovalVisible() {
        #expect(PlatformAgentConstraint.consequence(for: .watchVoiceOnly).contains("do not offer approval"))
        #expect(PlatformAgentConstraint.consequence(for: .iPadMultipleWindows).contains("scene"))
        #expect(PlatformAgentConstraint.consequence(for: .macUserSelectedFile).contains("security-scoped"))
        #expect(PlatformAgentConstraint.consequence(for: .spatialScene).contains("no extra authority"))
    }

    private func arguments(destination: String) -> RoutePlannerArguments {
        RoutePlannerArguments(
            destination: destination,
            admittedSourceNoteIDs: [FieldNotesFixture.kyotoID]
        )
    }

    private func argumentsJSON(destination: String) -> String {
        encode(arguments(destination: destination))
    }

    private func encode<Value: Encodable>(_ value: Value) -> String {
        let data = try! JSONEncoder().encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
