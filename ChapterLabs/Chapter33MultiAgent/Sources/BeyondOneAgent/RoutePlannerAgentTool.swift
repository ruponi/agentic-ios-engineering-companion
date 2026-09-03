import FieldNotesAgentLoop
import Foundation

public struct RoutePlannerArguments: Sendable, Codable, Equatable {
    public let destination: String
    public let admittedSourceNoteIDs: [UUID]

    public init(destination: String, admittedSourceNoteIDs: [UUID]) {
        self.destination = destination
        self.admittedSourceNoteIDs = admittedSourceNoteIDs
    }
}

public struct SpecialistRoute: Sendable, Codable, Equatable {
    public let steps: [String]
    public let sourceNoteIDs: [UUID]
    public let childTurns: Int

    public init(steps: [String], sourceNoteIDs: [UUID], childTurns: Int) {
        self.steps = steps
        self.sourceNoteIDs = sourceNoteIDs
        self.childTurns = childTurns
    }
}

public protocol RoutePlanning: Sendable {
    func route(for arguments: RoutePlannerArguments) async throws -> SpecialistRoute
}

/// The specialist is a read tool. Its result re-enters the outer loop through
/// `ToolResultEnvelope`; it has no initializer or method that can approve work.
public struct RoutePlannerAgentTool<Planner: RoutePlanning>: ReadAgentTool, Sendable {
    public typealias Arguments = RoutePlannerArguments
    public typealias Result = SpecialistRoute

    public static var name: String { "planRoute" }
    public static var effect: ToolEffectClassification { .read }
    public static var timeout: Duration { .milliseconds(250) }

    private let planner: Planner

    public init(planner: Planner) { self.planner = planner }

    public func call(_ arguments: RoutePlannerArguments) async throws -> SpecialistRoute {
        let route = try await planner.route(for: arguments)
        guard !route.steps.isEmpty,
              route.steps.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(route.sourceNoteIDs).isSubset(of: Set(arguments.admittedSourceNoteIDs))
        else {
            throw SpecialistFailure.unusableResult
        }
        return route
    }
}

public enum SpecialistFailure: Error, Sendable, Equatable, CustomStringConvertible {
    case unusableResult

    public var description: String { "unusableSpecialistResult" }
}

public struct BudgetedRoutePlanner: RoutePlanning, Sendable {
    private let budget: TreeTurnBudget
    private let childTurns: Int

    public init(budget: TreeTurnBudget, childTurns: Int = 2) {
        self.budget = budget
        self.childTurns = childTurns
    }

    public func route(for arguments: RoutePlannerArguments) async throws -> SpecialistRoute {
        try await budget.charge(turns: childTurns, atDepth: 1)
        return SpecialistRoute(
            steps: ["Retrieve passages for \(arguments.destination)", "Order the admitted stops"],
            sourceNoteIDs: arguments.admittedSourceNoteIDs,
            childTurns: childTurns
        )
    }
}

public struct UnusableRoutePlanner: RoutePlanning, Sendable {
    public init() {}

    public func route(for arguments: RoutePlannerArguments) async throws -> SpecialistRoute {
        SpecialistRoute(steps: [], sourceNoteIDs: arguments.admittedSourceNoteIDs, childTurns: 1)
    }
}

public struct SlowRoutePlanner: RoutePlanning, Sendable {
    public init() {}

    public func route(for arguments: RoutePlannerArguments) async throws -> SpecialistRoute {
        try await Task.sleep(for: .seconds(10))
        return SpecialistRoute(steps: [arguments.destination], sourceNoteIDs: [], childTurns: 1)
    }
}
