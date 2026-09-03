public struct TurnBudgetSnapshot: Sendable, Equatable {
    public let total: Int
    public let consumed: Int
    public let remaining: Int
    public let maximumDepth: Int
}

public enum TurnBudgetFailure: Error, Sendable, Equatable, CustomStringConvertible {
    case depthExceeded(maximum: Int, requested: Int)
    case exhausted(total: Int, requested: Int, consumed: Int)

    public var description: String {
        switch self {
        case .depthExceeded(let maximum, let requested):
            "depthExceeded(maximum:\(maximum),requested:\(requested))"
        case .exhausted(let total, let requested, let consumed):
            "treeBudgetExhausted(total:\(total),requested:\(requested),consumed:\(consumed))"
        }
    }
}

/// One ledger charges parent and child turns against a single finite total.
public actor TreeTurnBudget {
    private let total: Int
    private let maximumDepth: Int
    private var consumed = 0

    public init(total: Int, maximumDepth: Int) {
        precondition(total > 0)
        precondition(maximumDepth >= 0)
        self.total = total
        self.maximumDepth = maximumDepth
    }

    @discardableResult
    public func charge(turns: Int = 1, atDepth depth: Int) throws -> TurnBudgetSnapshot {
        precondition(turns > 0)
        guard depth <= maximumDepth else {
            throw TurnBudgetFailure.depthExceeded(maximum: maximumDepth, requested: depth)
        }
        guard consumed + turns <= total else {
            throw TurnBudgetFailure.exhausted(
                total: total,
                requested: turns,
                consumed: consumed
            )
        }
        consumed += turns
        return snapshot
    }

    public var snapshot: TurnBudgetSnapshot {
        TurnBudgetSnapshot(
            total: total,
            consumed: consumed,
            remaining: total - consumed,
            maximumDepth: maximumDepth
        )
    }
}
