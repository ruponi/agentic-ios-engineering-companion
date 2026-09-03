import FieldNotesAgentLoop

@main
struct PlacementTraceCommand {
    static func main() async {
        await printResult(name: "AVAILABLE", readiness: .available)
        await printResult(name: "INELIGIBLE", readiness: .deviceNotEligible)
        await printResult(name: "NOT READY", readiness: .modelNotReady)
        await printResult(name: "FRAMEWORK ABSENT", readiness: .frameworkNotPresent)
    }

    private static func printResult(name: String, readiness: ModelReadiness) async {
        let result = await PackingFeature(
            readiness: readiness,
            model: FieldNotesFixture.successfulModel(),
            searchTool: FieldNotesFixture.searchTool()
        ).makePackingBrief(request: FieldNotesFixture.request, query: "Kyoto")

        print("=== \(name) ===")
        print("placement=\(result.placement)")
        print("title=\(result.brief?.title ?? "none")")
        print("items=\(result.brief?.items.count ?? 0)")
    }
}
