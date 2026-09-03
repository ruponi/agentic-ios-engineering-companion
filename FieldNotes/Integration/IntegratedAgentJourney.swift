import FieldNotesAgentLoop
import Foundation
import SwiftData

enum AgentJourneyRoute: String, Sendable, Equatable {
    case onDevice = "on-device"
    case consentedCloud = "consented-cloud"
}

struct AgentPermissionSet: Sendable, Equatable {
    let allowsCloudInference: Bool
    let allowsDerivedMemory: Bool

    static func resolve(
        cloudGrant: CloudConsentGrant?,
        memoryGrant: MemoryConsentGrant?
    ) -> Self {
        Self(
            allowsCloudInference: cloudGrant != nil,
            allowsDerivedMemory: memoryGrant != nil
        )
    }

    static func validated(
        cloudGrant: CloudConsentGrant?,
        cloudLedger: CloudConsentLedger,
        memoryGrant: MemoryConsentGrant?,
        memoryLedger: MemoryConsentLedger
    ) async -> Self {
        let cloudIsActive: Bool
        if let cloudGrant {
            cloudIsActive = (try? await cloudLedger.validate(cloudGrant)) != nil
        } else {
            cloudIsActive = false
        }
        let memoryIsActive: Bool
        if let memoryGrant {
            memoryIsActive = (try? await memoryLedger.validate(memoryGrant)) != nil
        } else {
            memoryIsActive = false
        }
        return Self(
            allowsCloudInference: cloudIsActive,
            allowsDerivedMemory: memoryIsActive
        )
    }
}

/// Adapts durable notes to the loop without letting a long note violate the
/// loop's encoded 2,000-character tool-result budget.
@ModelActor
actor SwiftDataAgentSearchTool: ReadOnlyNoteSearching {
    static let maximumResults = 2
    static let maximumTitleCharacters = 80
    static let maximumBodyCharacters = 320

    func search(query: String) throws -> [FieldNotesAgentLoop.SearchDocument] {
        let notes = try modelContext.fetch(FetchDescriptor<StoredNote>())
        var index = NoteSearchIndex()
        index.rebuild(from: notes.map {
            SearchDocument(
                id: $0.id,
                title: $0.title,
                body: $0.body,
                modifiedAt: $0.modifiedAt ?? $0.createdAt
            )
        })
        let notesByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        return index.rankedIDs(for: query)
            .prefix(Self.maximumResults)
            .compactMap { notesByID[$0] }
            .map {
                FieldNotesAgentLoop.SearchDocument(
                    id: $0.id,
                    title: Self.promptSafe($0.title, limit: Self.maximumTitleCharacters),
                    body: Self.promptSafe($0.body, limit: Self.maximumBodyCharacters),
                    modifiedAt: $0.modifiedAt ?? $0.createdAt
                )
            }
    }

    private static func promptSafe(_ value: String, limit: Int) -> String {
        String(value.filter { !$0.isNewline && !$0.isASCIIControl }.prefix(limit))
    }
}

private extension Character {
    var isASCIIControl: Bool {
        unicodeScalars.allSatisfy { $0.isASCII && ($0.value < 32 || $0.value == 127) }
    }
}

struct IntegratedJourneyEvidence: Sendable, Equatable {
    let route: AgentJourneyRoute
    let localSearchCount: Int
    let trace: [TraceEvent]
    let auditRecord: AgentAuditRecord
    let signpostStages: [String]
}

struct IntegratedAgentJourney: Sendable {
    let modelContainer: ModelContainer

    func run(
        noteText: String,
        route: AgentJourneyRoute,
        permissions: AgentPermissionSet
    ) async throws -> IntegratedJourneyEvidence {
        guard route != .consentedCloud || permissions.allowsCloudInference else {
            throw CloudConsentFailure.notActive
        }

        let store = SwiftDataNoteStore(modelContainer: modelContainer)
        try await store.save(CaptureDraft(text: noteText))
        let localMatches = try await store.summaries(matching: "Kyoto")
        guard let source = localMatches.first else {
            throw AgentLoopFailure.toolFailed("captured note was not searchable")
        }

        let search = SwiftDataAgentSearchTool(modelContainer: modelContainer)
        let writeStore = VersionedNoteStore()
        let saveTool = SavePackingBriefTool(store: writeStore)
        let saveArguments = SavePackingBriefArguments(
            title: "Kyoto packing brief",
            items: ["Rain shell", "Rail pass", "Notebook"],
            sourceNoteIDs: [source.id]
        )
        let argumentsData = try JSONEncoder().encode(saveArguments)
        let model = ScriptedModel([
            .toolCall(ToolCall(
                id: "journey-search",
                name: FieldNotesSearchTool.name,
                argumentsJSON: #"{"query":"Kyoto"}"#
            )),
            .toolCall(ToolCall(
                id: "journey-save",
                name: SavePackingBriefTool.name,
                argumentsJSON: String(decoding: argumentsData, as: UTF8.self)
            ))
        ])
        let loop = AgentLoop(model: model, searchTool: search, saveTool: saveTool)
        let signposter = AgentSignposter()
        let correlationIdentifier = UUID()
        let requestInterval = signposter.begin(
            stage: .request,
            correlationIdentifier: correlationIdentifier
        )
        let outcome = await loop.run(
            request: "Find my Kyoto note and prepare a packing brief."
        )
        signposter.end(requestInterval, outcome: "suspended")

        guard case .suspended(let suspended) = outcome else {
            throw AgentLoopFailure.toolFailed("journey did not suspend for approval")
        }
        let amendment = PendingActionAmendment(original: suspended.pending)
            .replacingAction(with: .savePackingBrief(.init(
                title: "Kyoto field kit",
                items: ["Rain shell", "Rail pass", "Pocket notebook"],
                sourceNoteIDs: [source.id]
            )))
        let amendedRun = try suspended.replacingPending(with: amendment)
        let approval = try amendment.approve(pendingID: amendment.pending.id)

        let changeInterval = signposter.begin(
            stage: .change,
            correlationIdentifier: correlationIdentifier
        )
        let appliedOutcome = await loop.resume(amendedRun, with: approval)
        signposter.end(changeInterval, outcome: "applied")
        guard case .changeApplied(let change, let trace) = appliedOutcome else {
            throw AgentLoopFailure.toolFailed("amended action was not applied")
        }

        let audit = AgentAuditRecord(
            appliedChanges: [change],
            modelRuns: [ModelRunRecord(
                promptVersion: .packingBriefV1,
                operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                providerIdentifier: route.rawValue,
                correlationIdentifier: correlationIdentifier.uuidString
            )]
        )
        return IntegratedJourneyEvidence(
            route: route,
            localSearchCount: localMatches.count,
            trace: trace,
            auditRecord: audit,
            signpostStages: ["request", "change"]
        )
    }
}
