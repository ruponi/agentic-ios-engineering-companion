import FieldNotesAgentLoop
import SwiftUI

enum AgentPlacement: String, Equatable {
    case onDevice = "On this device"
    case consentedCloud = "Consented cloud service"
}

struct AgentSource: Identifiable, Equatable {
    let id: UUID
    let title: String
}

enum ChangeRecovery: Equatable {
    case undo(AppliedChange)
    case contactSupport(reference: String)
}

enum AgentExperienceState: Equatable {
    case available(AgentPlacement)
    case working
    case uncertain(sources: [AgentSource])
    case changed(sources: [AgentSource], recovery: ChangeRecovery)
}

struct AgentExperienceView: View {
    let state: AgentExperienceState
    var onUndo: (AppliedChange) -> Void = { _ in }
    var onContactSupport: (String) -> Void = { _ in }

    var body: some View {
        List {
            Section("FieldNotes Assistant") {
                stateSummary
            }
            if !sources.isEmpty {
                AgentSourceList(sources: sources)
            }
            if case .changed(_, let recovery) = state {
                Section("Correction") {
                    recoveryButton(recovery)
                }
            }
        }
        .navigationTitle("Assistant Status")
        .accessibilityIdentifier("agent-experience")
    }

    @ViewBuilder
    private var stateSummary: some View {
        switch state {
        case .available(let placement):
            LabeledContent("Can search notes and propose reversible changes", value: placement.rawValue)
        case .working:
            HStack {
                ProgressView()
                Text("Checking notes and preparing a proposal")
            }
            .accessibilityElement(children: .combine)
        case .uncertain:
            Label("The admitted notes do not support a confident answer", systemImage: "questionmark.circle")
        case .changed:
            Label("Change applied", systemImage: "checkmark.circle")
        }
    }

    @ViewBuilder
    private func recoveryButton(_ recovery: ChangeRecovery) -> some View {
        switch recovery {
        case .undo(let change):
            Button("Undo Change") { onUndo(change) }
                .accessibilityHint("Reverses the recorded change")
        case .contactSupport(let reference):
            Button("Contact Support") { onContactSupport(reference) }
                .accessibilityHint("Opens the human support route for this change")
        }
    }

    private var sources: [AgentSource] {
        switch state {
        case .uncertain(let sources), .changed(let sources, _): sources
        case .available, .working: []
        }
    }
}

struct AgentSourceList: View {
    let sources: [AgentSource]

    var body: some View {
        Section("Sources") {
            ForEach(sources) { source in
                LabeledContent {
                    Text(verbatim: source.id.uuidString)
                        .font(.caption)
                } label: {
                    Text(verbatim: source.title)
                }
                .accessibilityIdentifier("agent-source-\(source.id.uuidString)")
            }
        }
    }
}

#Preview("Uncertain with admitted source") {
    NavigationStack {
        AgentExperienceView(state: .uncertain(sources: [
            AgentSource(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                title: "Kyoto field trip"
            )
        ]))
    }
}
