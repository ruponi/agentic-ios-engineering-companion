import BeyondOneAgent
import FieldNotesAgentLoop
import Foundation

@main
struct MultiAgentTrace {
    static func main() async {
        print("TRACE specialist-invariants")
        let successBudget = TreeTurnBudget(total: 6, maximumDepth: 1)
        let successModel = ScriptedModel([
            .toolCall(.init(id: "specialist-1", name: "planRoute", argumentsJSON: argumentsJSON)),
            .toolCall(.init(id: "search-1", name: "searchNotes", argumentsJSON: FieldNotesFixture.kyotoArguments)),
            .final(.init(
                title: "Kyoto packing brief",
                items: ["Rain shell", "Rail pass", "Notebook"],
                sourceNoteIDs: [FieldNotesFixture.kyotoID]
            ))
        ])
        let clock = ContinuousClock()
        let start = clock.now
        let success = await AgentLoop(
            model: successModel,
            searchTool: FieldNotesFixture.searchTool(),
            registeredReadTools: [RegisteredReadTool(RoutePlannerAgentTool(
                planner: BudgetedRoutePlanner(budget: successBudget)
            ))]
        ).run(request: FieldNotesFixture.request)
        success.trace.forEach { print($0) }
        print("MEASURE specialist-elapsed=\(start.duration(to: clock.now)) child-turns=2 quality-delta=not-measured")

        print("TRACE tree-budget-exhaustion")
        let exhaustedBudget = TreeTurnBudget(total: 2, maximumDepth: 1)
        _ = try? await exhaustedBudget.charge(turns: 1, atDepth: 0)
        let exhaustedModel = ScriptedModel([
            .toolCall(.init(id: "specialist-2", name: "planRoute", argumentsJSON: argumentsJSON))
        ])
        let exhausted = await AgentLoop(
            model: exhaustedModel,
            searchTool: FieldNotesFixture.searchTool(),
            registeredReadTools: [RegisteredReadTool(RoutePlannerAgentTool(
                planner: BudgetedRoutePlanner(budget: exhaustedBudget, childTurns: 2)
            ))]
        ).run(request: FieldNotesFixture.request)
        exhausted.trace.forEach { print($0) }
    }

    private static let argumentsJSON: String = {
        let arguments = RoutePlannerArguments(
            destination: "Kyoto",
            admittedSourceNoteIDs: [FieldNotesFixture.kyotoID]
        )
        let data = try! JSONEncoder().encode(arguments)
        return String(decoding: data, as: UTF8.self)
    }()
}
