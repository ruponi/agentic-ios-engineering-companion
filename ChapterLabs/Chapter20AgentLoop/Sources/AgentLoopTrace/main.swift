import FieldNotesAgentLoop
import Foundation

@main
struct AgentLoopTraceCommand {
    static func main() async {
        await printTrace(
            name: "SUCCESS",
            outcome: AgentLoop(
                model: FieldNotesFixture.successfulModel(),
                searchTool: FieldNotesFixture.searchTool()
            ).run(request: FieldNotesFixture.request)
        )

        await printTrace(
            name: "REPEATED CALL",
            outcome: AgentLoop(
                model: FieldNotesFixture.repeatedCallModel(),
                searchTool: FieldNotesFixture.searchTool()
            ).run(request: FieldNotesFixture.request)
        )
    }

    private static func printTrace(name: String, outcome: AgentLoopOutcome) async {
        print("=== \(name) ===")
        for event in outcome.trace { print(event) }
    }
}
