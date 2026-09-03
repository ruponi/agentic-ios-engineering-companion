import FieldNotesAgentLoop
import Foundation
import SwiftData

/// Persists the package's single `PersonalContextRecord` value definition.
/// Consent validation remains at the package boundary; SwiftData owns only the
/// durable representation declared by `FieldNotesSchemaV3`.
@ModelActor
actor SwiftDataPersonalContextStore {
    func regenerate(
        _ records: [PersonalContextRecord],
        grant: MemoryConsentGrant,
        ledger: MemoryConsentLedger,
        now: Date
    ) async throws {
        try await ledger.validate(grant)
        for stored in try modelContext.fetch(FetchDescriptor<StoredPersonalContext>()) {
            modelContext.delete(stored)
        }
        for record in records where record.expiresAt > now {
            modelContext.insert(StoredPersonalContext(
                id: record.id,
                value: record.value,
                sourceNoteID: record.sourceNoteID,
                derivedAt: record.derivedAt,
                derivationVersion: record.derivationVersion,
                expiresAt: record.expiresAt
            ))
        }
        try modelContext.save()
    }

    func records(
        grant: MemoryConsentGrant,
        ledger: MemoryConsentLedger,
        now: Date
    ) async throws -> [PersonalContextRecord] {
        try await ledger.validate(grant)
        let stored = try modelContext.fetch(FetchDescriptor<StoredPersonalContext>())
        var current: [PersonalContextRecord] = []
        for record in stored {
            if record.expiresAt <= now {
                modelContext.delete(record)
            } else {
                current.append(Self.value(record))
            }
        }
        try modelContext.save()
        return current.sorted { $0.sourceNoteID.uuidString < $1.sourceNoteID.uuidString }
    }

    func export(
        grant: MemoryConsentGrant,
        ledger: MemoryConsentLedger,
        now: Date
    ) async throws -> String {
        let current = try await records(grant: grant, ledger: ledger, now: now)
        guard !current.isEmpty else { return "FieldNotes personal context\nNo retained records.\n" }
        return (["FieldNotes personal context"] + current.map {
            "- \($0.value)\n  Source note: \($0.sourceNoteID.uuidString)\n  Rule: \($0.derivationVersion)"
        }).joined(separator: "\n") + "\n"
    }

    private static func value(_ stored: StoredPersonalContext) -> PersonalContextRecord {
        PersonalContextRecord(
            id: stored.id,
            value: stored.value,
            sourceNoteID: stored.sourceNoteID,
            derivedAt: stored.derivedAt,
            derivationVersion: stored.derivationVersion,
            expiresAt: stored.expiresAt
        )
    }
}
