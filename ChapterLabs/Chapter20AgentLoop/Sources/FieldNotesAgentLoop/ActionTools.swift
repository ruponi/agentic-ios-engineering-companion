import Foundation

public struct VersionedNote: Sendable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var body: String
    public var tags: [String]

    public init(id: UUID = UUID(), title: String, body: String, tags: [String] = []) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
    }
}

public actor VersionedNoteStore {
    private struct ChangeRecord: Sendable {
        let change: AppliedChange
        let before: VersionedNote?
        let after: VersionedNote
    }

    private var notes: [UUID: VersionedNote]
    private var changesByKey: [UUID: ChangeRecord] = [:]

    public init(notes: [VersionedNote] = []) {
        self.notes = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
    }

    public func allNotes() -> [VersionedNote] {
        notes.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    fileprivate func apply(_ pending: PendingAction, approval: ApprovedAction) throws -> AppliedChange {
        guard approval.pendingID == pending.id, approval.action == pending.action else {
            throw ActionValidationFailure.approvalMismatch
        }
        if let record = changesByKey[pending.idempotencyKey] {
            guard record.change.action == pending.action else {
                throw ActionValidationFailure.idempotencyConflict
            }
            return AppliedChange(
                id: record.change.id,
                pendingID: pending.id,
                idempotencyKey: pending.idempotencyKey,
                action: pending.action,
                replayed: true
            )
        }

        let before: VersionedNote?
        let after: VersionedNote
        switch pending.action {
        case .savePackingBrief(let arguments):
            guard !arguments.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (1...6).contains(arguments.items.count),
                  !arguments.sourceNoteIDs.isEmpty
            else { throw ActionValidationFailure.invalidProductRule("packing brief") }
            before = nil
            after = VersionedNote(
                title: arguments.title,
                body: arguments.items.map { "- \($0)" }.joined(separator: "\n")
            )
        case .tagNote(let arguments):
            let normalizedTag = arguments.tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTag.isEmpty, normalizedTag.count <= 24, !normalizedTag.contains("#"),
                  var note = notes[arguments.noteID]
            else { throw ActionValidationFailure.invalidProductRule("tag") }
            before = note
            if !note.tags.contains(normalizedTag) { note.tags.append(normalizedTag) }
            after = note
        case .deleteNote:
            throw ActionValidationFailure.consequentialActionNotRegistered
        }

        notes[after.id] = after
        let change = AppliedChange(
            id: UUID(), pendingID: pending.id, idempotencyKey: pending.idempotencyKey,
            action: pending.action, replayed: false
        )
        changesByKey[pending.idempotencyKey] = ChangeRecord(
            change: change, before: before, after: after
        )
        return change
    }

    public func revert(_ change: AppliedChange) throws {
        guard let record = changesByKey[change.idempotencyKey], record.change.id == change.id else {
            throw ActionValidationFailure.unknownChange
        }
        if let before = record.before { notes[before.id] = before } else { notes[record.after.id] = nil }
        changesByKey[change.idempotencyKey] = nil
    }
}

public protocol ApprovalRequiredAgentTool: AgentTool {
    func call(_ pending: PendingAction, approval: ApprovedAction) async throws -> AppliedChange
}

public struct SavePackingBriefTool: ApprovalRequiredAgentTool {
    public static let name = "savePackingBrief"
    public static let effect = ToolEffectClassification.reversibleWrite
    public static let timeout: Duration = .seconds(2)
    public typealias Arguments = SavePackingBriefArguments
    public typealias Result = AppliedChange
    private let store: VersionedNoteStore

    public init(store: VersionedNoteStore) { self.store = store }

    public func call(_ pending: PendingAction, approval: ApprovedAction) async throws -> AppliedChange {
        try await store.apply(pending, approval: approval)
    }
}

public struct TagNoteTool: ApprovalRequiredAgentTool {
    public static let name = "tagNote"
    public static let effect = ToolEffectClassification.reversibleWrite
    public static let timeout: Duration = .seconds(2)
    public typealias Arguments = TagNoteArguments
    public typealias Result = AppliedChange
    private let store: VersionedNoteStore

    public init(store: VersionedNoteStore) { self.store = store }

    public func call(_ pending: PendingAction, approval: ApprovedAction) async throws -> AppliedChange {
        try await store.apply(pending, approval: approval)
    }
}

public enum DeleteNoteTool: AgentTool {
    public static let name = "deleteNote"
    public static let effect = ToolEffectClassification.consequential
    public static let timeout: Duration = .seconds(2)
    public typealias Arguments = DeleteNoteArguments
    public typealias Result = NeverResult
}

public struct NeverResult: Sendable, Codable, Equatable {}
