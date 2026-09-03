import Foundation

public struct SearchDocument: Sendable, Codable, Equatable {
    public let id: UUID
    public let title: String
    public let body: String
    public let modifiedAt: Date

    public init(id: UUID, title: String, body: String, modifiedAt: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.modifiedAt = modifiedAt
    }
}

public struct NoteSearchIndex: Sendable {
    private var documents: [UUID: SearchDocument] = [:]
    private var postings: [String: [UUID: Int]] = [:]

    public init() {}

    public mutating func rebuild(from documents: [SearchDocument]) {
        self.documents = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
        postings = [:]
        for document in documents {
            add(tokens(in: document.title), id: document.id, weight: 3)
            add(tokens(in: document.body), id: document.id, weight: 1)
        }
    }

    public func search(_ query: String) -> [SearchDocument] {
        rankedIDs(for: query).compactMap { documents[$0] }
    }

    private func rankedIDs(for query: String) -> [UUID] {
        let queryTokens = tokens(in: query)
        guard !queryTokens.isEmpty else {
            return documents.values.sorted(by: order).map(\.id)
        }

        var scores: [UUID: Int] = [:]
        var candidates: Set<UUID>?
        for queryToken in queryTokens {
            var matchingIDs: Set<UUID> = []
            for (token, weights) in postings where token.hasPrefix(queryToken) {
                for (id, weight) in weights {
                    matchingIDs.insert(id)
                    scores[id, default: 0] += weight
                }
            }
            candidates = candidates.map { $0.intersection(matchingIDs) } ?? matchingIDs
        }
        return (candidates ?? []).sorted {
            if scores[$0, default: 0] != scores[$1, default: 0] {
                return scores[$0, default: 0] > scores[$1, default: 0]
            }
            return order(documents[$0]!, documents[$1]!)
        }
    }

    private func order(_ left: SearchDocument, _ right: SearchDocument) -> Bool {
        if left.modifiedAt != right.modifiedAt { return left.modifiedAt > right.modifiedAt }
        return left.id.uuidString < right.id.uuidString
    }

    private mutating func add(_ tokens: Set<String>, id: UUID, weight: Int) {
        for token in tokens { postings[token, default: [:]][id] = weight }
    }

    private func tokens(in text: String) -> Set<String> {
        Set(text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .split { !$0.isLetter && !$0.isNumber }
        .map(String.init))
    }
}

public struct SearchArguments: Sendable, Codable, Equatable {
    public let query: String

    public init(query: String) {
        self.query = query
    }
}

public enum SearchToolError: Error, Sendable, Equatable {
    case recoverable(String)
    case fatal(String)
}

public protocol ReadOnlyNoteSearching: Sendable {
    func search(query: String) async throws -> [SearchDocument]
}

public struct FieldNotesSearchTool: ReadOnlyNoteSearching, ReadAgentTool, Sendable {
    public static let name = "searchNotes"
    public static let effect = ToolEffectClassification.read
    public static let timeout: Duration = .seconds(1)
    public typealias Arguments = SearchArguments
    public typealias Result = [SearchDocument]
    private let index: NoteSearchIndex
    private let recoverableFailureQueries: Set<String>
    private let fatalFailureQueries: Set<String>

    public init(
        documents: [SearchDocument],
        recoverableFailureQueries: Set<String> = [],
        fatalFailureQueries: Set<String> = []
    ) {
        var index = NoteSearchIndex()
        index.rebuild(from: documents)
        self.index = index
        self.recoverableFailureQueries = recoverableFailureQueries
        self.fatalFailureQueries = fatalFailureQueries
    }

    public func search(query: String) async throws -> [SearchDocument] {
        try Task.checkCancellation()
        if recoverableFailureQueries.contains(query) {
            throw SearchToolError.recoverable("temporary search failure")
        }
        if fatalFailureQueries.contains(query) {
            throw SearchToolError.fatal("search index unavailable")
        }
        return index.search(query)
    }

    public func call(_ arguments: SearchArguments) async throws -> [SearchDocument] {
        try await search(query: arguments.query)
    }
}
