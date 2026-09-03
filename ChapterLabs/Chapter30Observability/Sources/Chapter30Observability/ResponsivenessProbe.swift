import Foundation

public struct ResponsivenessMeasurement: Sendable, Equatable {
    public let timeToFirstOutputMilliseconds: Double
    public let totalMilliseconds: Double
    public let environment: String

    public init(
        timeToFirstOutputMilliseconds: Double,
        totalMilliseconds: Double,
        environment: String
    ) {
        self.timeToFirstOutputMilliseconds = timeToFirstOutputMilliseconds
        self.totalMilliseconds = totalMilliseconds
        self.environment = environment
    }
}

public enum PerceivedResponsivenessProbe {
    public static func run() async throws -> ResponsivenessMeasurement {
        let clock = ContinuousClock()
        let start = clock.now
        try await Task.sleep(for: .milliseconds(20))
        let first = start.duration(to: clock.now)
        try await Task.sleep(for: .milliseconds(15))
        let total = start.duration(to: clock.now)
        return ResponsivenessMeasurement(
            timeToFirstOutputMilliseconds: milliseconds(first),
            totalMilliseconds: milliseconds(total),
            environment: ProcessInfo.processInfo.operatingSystemVersionString
        )
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
