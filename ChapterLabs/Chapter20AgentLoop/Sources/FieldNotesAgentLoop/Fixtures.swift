import Foundation

public actor ScriptedModel: AgentModel {
    private var proposals: [AgentProposal]

    public init(_ proposals: [AgentProposal]) {
        self.proposals = proposals
    }

    public func respond(to context: AgentContext) async throws -> AgentProposal {
        guard !proposals.isEmpty else { throw ScriptedModelError.exhausted }
        return proposals.removeFirst()
    }
}

public enum ScriptedModelError: Error, Sendable {
    case exhausted
}

public struct CancellingModel: AgentModel, Sendable {
    public init() {}

    public func respond(to context: AgentContext) async throws -> AgentProposal {
        throw CancellationError()
    }
}

public struct CancellingSearchTool: ReadOnlyNoteSearching, Sendable {
    public init() {}

    public func search(query: String) async throws -> [SearchDocument] {
        throw CancellationError()
    }
}

public enum FieldNotesFixture {
    public static let kyotoID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    public static let gardenID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    public static let documents = [
        SearchDocument(
            id: kyotoID,
            title: "Kyoto field trip",
            body: "Pack a rain shell, rail pass, and notebook.",
            modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ),
        SearchDocument(
            id: gardenID,
            title: "Garden jobs",
            body: "Sharpen shears before Saturday.",
            modifiedAt: Date(timeIntervalSince1970: 1_699_000_000)
        )
    ]

    public static let request = "Find my note about Kyoto and prepare a short packing brief."
    public static let kyotoArguments = #"{"query":"Kyoto"}"#

    public static func successfulModel() -> ScriptedModel {
        ScriptedModel([
            .toolCall(ToolCall(id: "call-1", name: "searchNotes", argumentsJSON: kyotoArguments)),
            .final(PackingBrief(
                title: "Kyoto packing brief",
                items: ["Rain shell", "Rail pass", "Notebook"],
                sourceNoteIDs: [kyotoID]
            ))
        ])
    }

    public static func repeatedCallModel() -> ScriptedModel {
        ScriptedModel([
            .toolCall(ToolCall(id: "call-1", name: "searchNotes", argumentsJSON: kyotoArguments)),
            .toolCall(ToolCall(id: "call-2", name: "searchNotes", argumentsJSON: kyotoArguments))
        ])
    }

    public static func searchTool() -> FieldNotesSearchTool {
        FieldNotesSearchTool(documents: documents)
    }
}

public struct DeterministicPackingWorkflow: Sendable {
    private let searchTool: any ReadOnlyNoteSearching

    public init(searchTool: any ReadOnlyNoteSearching) {
        self.searchTool = searchTool
    }

    public func makeBrief(query: String) async throws -> PackingBrief? {
        let matches = try await searchTool.search(query: query)
        guard let note = matches.first else { return nil }
        let items = note.body
            .split(separator: ",")
            .map { item in
                item.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    .capitalized
            }
        return PackingBrief(
            title: "\(query) packing brief",
            items: items,
            sourceNoteIDs: [note.id]
        )
    }
}
