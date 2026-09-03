import FieldNotesAgentLoop
import SwiftUI

struct WriteApprovalView: View {
    @State private var review: PendingActionAmendment
    @State private var draftTitle: String
    @State private var draftTag: String
    @State private var amendmentCount = 0

    var onApprove: (PendingAction) -> Void
    var onDecline: () -> Void

    init(
        pending: PendingAction,
        onApprove: @escaping (PendingAction) -> Void,
        onDecline: @escaping () -> Void
    ) {
        _review = State(initialValue: PendingActionAmendment(original: pending))
        switch pending.action {
        case .savePackingBrief(let arguments):
            _draftTitle = State(initialValue: arguments.title)
            _draftTag = State(initialValue: "")
        case .tagNote(let arguments):
            _draftTitle = State(initialValue: "")
            _draftTag = State(initialValue: arguments.tag)
        case .deleteNote:
            _draftTitle = State(initialValue: "")
            _draftTag = State(initialValue: "")
        }
        self.onApprove = onApprove
        self.onDecline = onDecline
    }

    var body: some View {
        Form {
            Section {
                Label("Review Proposed Change", systemImage: "checkmark.shield")
                    .font(.title2.bold())
                Text("Check the exact values. Editing creates a replacement proposal.")
                    .foregroundStyle(.secondary)
            }

            Section("Action") {
                LabeledContent("Tool", value: toolName)
                LabeledContent("Effect", value: review.pending.effect.rawValue)
                LabeledContent("Proposal ID", value: review.pending.id.uuidString)
                    .accessibilityIdentifier("proposal-id")
                LabeledContent("Idempotency key", value: review.pending.idempotencyKey.uuidString)
                editableFields
            }

            Section {
                Button("Apply Amendment", action: amend)
                    .disabled(!hasDraftChange)
                    .accessibilityIdentifier("amend-write")
                Button("Approve Exact Change") { onApprove(review.pending) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("approve-write")
                Button("Decline", role: .cancel, action: onDecline)
                    .accessibilityIdentifier("decline-write")
            }
        }
        .accessibilityIdentifier("write-approval")
        .sensoryFeedback(.success, trigger: amendmentCount)
    }

    @ViewBuilder
    private var editableFields: some View {
        switch review.pending.action {
        case .savePackingBrief(let arguments):
            TextField("Title", text: $draftTitle)
                .accessibilityIdentifier("approval-title")
            ForEach(actionFields(arguments.items, pendingID: review.pending.id)) { field in
                LabeledContent(field.label, value: field.value)
            }
            LabeledContent("Source notes", value: uuidList(arguments.sourceNoteIDs))
        case .tagNote(let arguments):
            LabeledContent("Note ID", value: arguments.noteID.uuidString)
            TextField("Tag", text: $draftTag)
                .accessibilityIdentifier("approval-tag")
        case .deleteNote(let arguments):
            LabeledContent("Note ID", value: arguments.noteID.uuidString)
        }
    }

    private var hasDraftChange: Bool {
        switch review.pending.action {
        case .savePackingBrief(let arguments): draftTitle != arguments.title
        case .tagNote(let arguments): draftTag != arguments.tag
        case .deleteNote: false
        }
    }

    private func amend() {
        let action: NoteWriteAction
        switch review.pending.action {
        case .savePackingBrief(let arguments):
            action = .savePackingBrief(.init(
                title: draftTitle,
                items: arguments.items,
                sourceNoteIDs: arguments.sourceNoteIDs
            ))
        case .tagNote(let arguments):
            action = .tagNote(.init(noteID: arguments.noteID, tag: draftTag))
        case .deleteNote:
            return
        }
        review = review.replacingAction(with: action)
        amendmentCount += 1
    }

    private var toolName: String {
        switch review.pending.action {
        case .savePackingBrief: "savePackingBrief"
        case .tagNote: "tagNote"
        case .deleteNote: "deleteNote"
        }
    }

    private func uuidList(_ ids: [UUID]) -> String {
        ids.map(\.uuidString).joined(separator: ", ")
    }

    private func actionFields(_ items: [String], pendingID: UUID) -> [ApprovalField] {
        items.enumerated().map { index, item in
            ApprovalField(id: "\(pendingID)-\(index)", label: "Item \(index + 1)", value: item)
        }
    }
}

private struct ApprovalField: Identifiable {
    let id: String
    let label: String
    let value: String
}

#Preview("Editable write approval") {
    WriteApprovalView(
        pending: PendingAction(
            callID: "preview-write",
            effect: .reversibleWrite,
            action: .savePackingBrief(.init(
                title: "Kyoto packing brief",
                items: ["Rain shell", "Rail pass", "Notebook"],
                sourceNoteIDs: [UUID(uuidString: "11111111-1111-1111-1111-111111111111")!]
            ))
        ),
        onApprove: { _ in },
        onDecline: {}
    )
}
