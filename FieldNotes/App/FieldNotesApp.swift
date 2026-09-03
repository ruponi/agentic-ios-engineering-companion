import FieldNotesAgentLoop
import SwiftUI

@main
struct FieldNotesApp: App {
    private let store: SwiftDataNoteStore?
    private let launchFailure: FieldNotesLaunchFailure?

    init() {
        switch FieldNotesPersistence.open() {
        case .success(let container):
            store = SwiftDataNoteStore(modelContainer: container)
            launchFailure = nil
        case .failure(let failure):
            store = nil
            launchFailure = failure
        }
    }

    var body: some Scene {
        WindowGroup {
            if Self.showsAgentExperienceForUITesting {
                NavigationStack {
                    AgentExperienceView(state: .uncertain(sources: [Self.agentSourceFixture]))
                }
            } else if Self.showsVoiceInteractionForUITesting {
                VoiceInteractionView(
                    pending: Self.writeApprovalFixture,
                    onTransferToScreen: {},
                    onDecline: {}
                )
            } else if Self.showsWriteApprovalForUITesting {
                WriteApprovalView(
                    pending: Self.writeApprovalFixture,
                    onApprove: { _ in },
                    onDecline: {}
                )
            } else if let fallbackState = Self.fallbackStateForUITesting {
                IntelligenceFallbackView(state: fallbackState)
            } else if let store {
                FieldNotesRootView(store: store)
            } else {
                PersistenceFailureView(
                    message: launchFailure?.message ?? "Your notes could not be opened."
                )
            }
        }
    }

    private static var showsWriteApprovalForUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-show-write-approval")
    }

    private static var showsVoiceInteractionForUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-show-voice-interaction")
    }

    private static var showsAgentExperienceForUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-show-agent-experience")
    }

    private static let agentSourceFixture = AgentSource(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        title: "Kyoto field trip"
    )

    private static let writeApprovalFixture = PendingAction(
        callID: "ui-write-1",
        idempotencyKey: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        effect: .reversibleWrite,
        action: .savePackingBrief(.init(
            title: "Kyoto packing brief",
            items: ["Rain shell", "Rail pass", "Notebook"],
            sourceNoteIDs: [UUID(uuidString: "11111111-1111-1111-1111-111111111111")!]
        ))
    )

    private static var fallbackStateForUITesting: IntelligenceFallbackState? {
        guard let value = ProcessInfo.processInfo.environment["FIELDNOTES_INTELLIGENCE_STATE"] else {
            return nil
        }
        return IntelligenceFallbackState(rawValue: value)
    }
}
