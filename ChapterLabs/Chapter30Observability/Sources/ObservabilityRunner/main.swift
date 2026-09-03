import Chapter30Observability
import Foundation

@main
struct ObservabilityRunnerCommand {
    static func main() async throws {
        let budget = try await AgentBudgetObserver.canonicalRequest()
        let responsiveness = try await PerceivedResponsivenessProbe.run()
        let offRoute = await PackingBriefReleaseRouter(flag: .disabled).makeBrief()
        let trace = try ContentFreeTraceFixture.successfulRequest()

        print("budget turns=\(budget.modelTurns)/4 messages=\(budget.maximumRetainedMessages)/6 tool-characters=\(budget.toolResultCharacters)/2000 recoverable=\(budget.recoverableToolFailures)/1")
        print(String(format: "responsiveness first-ms=%.2f total-ms=%.2f environment=%@", responsiveness.timeToFirstOutputMilliseconds, responsiveness.totalMilliseconds, responsiveness.environment))
        print("off-route=\(offRoute.route.rawValue) brief=\(offRoute.brief != nil)")
        print(trace.rendered())
        print("absent=\(StitchedAgentTrace.deliberatelyAbsentFields.joined(separator: ","))")
    }
}
