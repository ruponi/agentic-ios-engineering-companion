import Foundation

/// What the index needs to rank a note. Deliberately not `StoredNote`: managed
/// objects stay inside their actor.
struct SearchDocument: Sendable, Equatable {
    let id: UUID
    let title: String
    let body: String
    let modifiedAt: Date
}

/// A small inverted index: normalised token to the notes containing it.
///
/// Not persisted, because storage already holds every fact needed to rebuild
/// it. That is what makes the source-of-truth boundary visible.
struct NoteSearchIndex: Sendable {
    private var documents: [UUID: SearchDocument] = [:]
    private var postings: [String: [UUID: Int]] = [:]

    mutating func rebuild(from documents: [SearchDocument]) {
        self.documents = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
        postings = [:]
        for document in documents {
            add(tokens(in: document.title), id: document.id, weight: 3)
            add(tokens(in: document.body), id: document.id, weight: 1)
        }
    }

    /// Every query token must match. Score breaks the first tie, then
    /// modification time, then UUID — so ordering is deterministic.
    func rankedIDs(for query: String) -> [UUID] {
        let queryTokens = tokens(in: query)
        guard !queryTokens.isEmpty else {
            return documents.values.sorted(by: Self.isOrderedBefore).map(\.id)
        }

        var scores: [UUID: Int] = [:]
        var candidates: Set<UUID>?

        for queryToken in queryTokens {
            var matching: Set<UUID> = []
            for (token, weights) in postings where token.hasPrefix(queryToken) {
                for (id, weight) in weights {
                    matching.insert(id)
                    scores[id, default: 0] += weight
                }
            }
            candidates = candidates.map { $0.intersection(matching) } ?? matching
        }

        return (candidates ?? []).sorted { left, right in
            let leftScore = scores[left, default: 0]
            let rightScore = scores[right, default: 0]
            if leftScore != rightScore { return leftScore > rightScore }
            guard let leftDocument = documents[left], let rightDocument = documents[right] else {
                return left.uuidString < right.uuidString
            }
            return Self.isOrderedBefore(leftDocument, rightDocument)
        }
    }

    private static func isOrderedBefore(_ left: SearchDocument, _ right: SearchDocument) -> Bool {
        if left.modifiedAt != right.modifiedAt { return left.modifiedAt > right.modifiedAt }
        return left.id.uuidString < right.id.uuidString
    }

    private mutating func add(_ tokens: Set<String>, id: UUID, weight: Int) {
        for token in tokens {
            postings[token, default: [:]][id, default: 0] += weight
        }
    }

    /// Case and diacritic folding under a fixed locale keeps tests repeatable.
    /// Test tokenisation and ranking against the supported localisation matrix
    /// before shipping.
    private func tokens(in text: String) -> Set<String> {
        let normalized = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return Set(normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }
}
