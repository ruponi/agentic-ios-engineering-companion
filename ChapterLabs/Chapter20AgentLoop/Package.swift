// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FieldNotesAgentLoop",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FieldNotesAgentLoop", targets: ["FieldNotesAgentLoop"]),
        .executable(name: "AgentLoopTrace", targets: ["AgentLoopTrace"]),
        .executable(name: "PlacementTrace", targets: ["PlacementTrace"])
    ],
    targets: [
        .target(
            name: "FieldNotesAgentLoop",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        .executableTarget(
            name: "AgentLoopTrace",
            dependencies: ["FieldNotesAgentLoop"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        .executableTarget(
            name: "PlacementTrace",
            dependencies: ["FieldNotesAgentLoop"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        .testTarget(
            name: "FieldNotesAgentLoopTests",
            dependencies: ["FieldNotesAgentLoop"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        )
    ],
    swiftLanguageModes: [.v6]
)
