import Foundation

public struct PersonalContextRecord: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let value: String
    public let sourceNoteID: UUID
    public let derivedAt: Date
    public let derivationVersion: String
    public let expiresAt: Date

    public init(
        id: UUID = UUID(),
        value: String,
        sourceNoteID: UUID,
        derivedAt: Date,
        derivationVersion: String,
        expiresAt: Date
    ) {
        self.id = id
        self.value = value
        self.sourceNoteID = sourceNoteID
        self.derivedAt = derivedAt
        self.derivationVersion = derivationVersion
        self.expiresAt = expiresAt
    }
}

public struct RetentionWindow: Sendable, Codable, Equatable {
    public let seconds: TimeInterval

    public init(seconds: TimeInterval) {
        precondition(seconds > 0)
        self.seconds = seconds
    }

    public func expiration(after date: Date) -> Date {
        date.addingTimeInterval(seconds)
    }
}

public struct MemoryConsentGrant: Sendable, Equatable {
    fileprivate let id: UUID
    fileprivate init(id: UUID) { self.id = id }
}

public enum MemoryConsentFailure: Error, Sendable, Equatable {
    case inactiveGrant
}

public actor MemoryConsentLedger {
    private var activeGrantIDs: Set<UUID> = []

    public init() {}

    public func grant() -> MemoryConsentGrant {
        let grant = MemoryConsentGrant(id: UUID())
        activeGrantIDs.insert(grant.id)
        return grant
    }

    public func revoke(_ grant: MemoryConsentGrant) {
        activeGrantIDs.remove(grant.id)
    }

    public func validate(_ grant: MemoryConsentGrant) throws {
        guard activeGrantIDs.contains(grant.id) else {
            throw MemoryConsentFailure.inactiveGrant
        }
    }
}

public struct RetrievedPassage: Sendable, Codable, Equatable {
    public let noteID: UUID
    public let text: String
    public let modifiedAt: Date

    public init(noteID: UUID, text: String, modifiedAt: Date) {
        self.noteID = noteID
        self.text = text
        self.modifiedAt = modifiedAt
    }
}

public protocol PassageRanking: Sendable {
    func rank(query: String, documents: [SearchDocument]) async throws -> [RetrievedPassage]
}

public struct LexicalPassageRanker: PassageRanking, Sendable {
    public init() {}

    public func rank(
        query: String,
        documents: [SearchDocument]
    ) async throws -> [RetrievedPassage] {
        var index = NoteSearchIndex()
        index.rebuild(from: documents)
        return index.search(query).map {
            RetrievedPassage(noteID: $0.id, text: $0.body, modifiedAt: $0.modifiedAt)
        }
    }
}

public protocol EmbeddingSimilarity: Sendable {
    var isAvailable: Bool { get }
    func score(query: String, passage: RetrievedPassage) async throws -> Double
}

public struct EmbeddingPassageRanker<Similarity: EmbeddingSimilarity>:
    PassageRanking, Sendable
{
    private let lexical = LexicalPassageRanker()
    private let similarity: Similarity

    public init(similarity: Similarity) { self.similarity = similarity }

    public func rank(
        query: String,
        documents: [SearchDocument]
    ) async throws -> [RetrievedPassage] {
        let candidates = try await lexical.rank(query: query, documents: documents)
        guard similarity.isAvailable else { return candidates }

        var scored: [(RetrievedPassage, Double)] = []
        for passage in candidates {
            scored.append((passage, try await similarity.score(query: query, passage: passage)))
        }
        return scored.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0.noteID.uuidString < $1.0.noteID.uuidString
        }.map(\.0)
    }
}

public actor PersonalContextStore {
    public typealias Derivation = @Sendable (SearchDocument) -> String?

    private let grant: MemoryConsentGrant
    private let ledger: MemoryConsentLedger
    private let retention: RetentionWindow
    private var recordsByID: [UUID: PersonalContextRecord] = [:]

    public init(
        grant: MemoryConsentGrant,
        ledger: MemoryConsentLedger,
        retention: RetentionWindow
    ) {
        self.grant = grant
        self.ledger = ledger
        self.retention = retention
    }

    public func regenerate(
        from documents: [SearchDocument],
        derivationVersion: String,
        now: Date,
        derive: Derivation
    ) async throws {
        try await ledger.validate(grant)
        let records = documents.compactMap { document -> PersonalContextRecord? in
            guard let value = derive(document) else { return nil }
            return PersonalContextRecord(
                value: value,
                sourceNoteID: document.id,
                derivedAt: now,
                derivationVersion: derivationVersion,
                expiresAt: retention.expiration(after: now)
            )
        }
        recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    }

    public func records(now: Date) async throws -> [PersonalContextRecord] {
        try await ledger.validate(grant)
        recordsByID = recordsByID.filter { $0.value.expiresAt > now }
        return recordsByID.values.sorted { $0.sourceNoteID.uuidString < $1.sourceNoteID.uuidString }
    }

    public func deleteRecords(derivedFrom noteID: UUID) async throws {
        try await ledger.validate(grant)
        recordsByID = recordsByID.filter { $0.value.sourceNoteID != noteID }
    }

    public func export(now: Date) async throws -> String {
        let current = try await records(now: now)
        guard !current.isEmpty else { return "FieldNotes personal context\nNo retained records.\n" }
        let lines = current.map {
            "- \($0.value)\n  Source note: \($0.sourceNoteID.uuidString)\n  Derived: \($0.derivedAt.ISO8601Format())\n  Rule: \($0.derivationVersion)\n  Expires: \($0.expiresAt.ISO8601Format())"
        }
        return (["FieldNotes personal context"] + lines).joined(separator: "\n") + "\n"
    }
}
