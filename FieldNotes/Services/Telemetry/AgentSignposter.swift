import Foundation
import OSLog

struct AgentSignposter: Sendable {
    enum Stage: String, Sendable {
        case request
        case backend
        case model
        case tool
        case change
    }

    private let signposter = OSSignposter(
        subsystem: "com.example.MasteringAgenticAI.FieldNotes",
        category: "agent-request"
    )

    func begin(stage: Stage, correlationIdentifier: UUID) -> OSSignpostIntervalState {
        signposter.beginInterval(
            "Agent request",
            id: signposter.makeSignpostID(),
            "stage=\(stage.rawValue, privacy: .public) correlation=\(correlationIdentifier.uuidString, privacy: .private(mask: .hash))"
        )
    }

    func end(_ state: OSSignpostIntervalState, outcome: String) {
        signposter.endInterval(
            "Agent request",
            state,
            "outcome=\(outcome, privacy: .public)"
        )
    }
}

struct CloudTaskMetricSample: Sendable, Equatable {
    let taskDurationMilliseconds: Int
    let transactionCount: Int
    let redirectCount: Int

    init(metrics: URLSessionTaskMetrics) {
        taskDurationMilliseconds = Int(metrics.taskInterval.duration * 1_000)
        transactionCount = metrics.transactionMetrics.count
        redirectCount = metrics.redirectCount
    }
}

struct DeviceOperatingCondition: Sendable, Equatable {
    let thermalState: ProcessInfo.ThermalState
    let lowPowerModeEnabled: Bool

    static var current: Self {
        Self(
            thermalState: ProcessInfo.processInfo.thermalState,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}
