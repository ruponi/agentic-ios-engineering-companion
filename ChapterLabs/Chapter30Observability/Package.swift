// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Chapter30Observability",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Chapter30Observability", targets: ["Chapter30Observability"]),
        .executable(name: "ObservabilityRunner", targets: ["ObservabilityRunner"]),
    ],
    dependencies: [
        .package(path: "../Chapter20AgentLoop"),
    ],
    targets: [
        .target(
            name: "Chapter30Observability",
            dependencies: [
                .product(name: "FieldNotesAgentLoop", package: "Chapter20AgentLoop"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        .executableTarget(
            name: "ObservabilityRunner",
            dependencies: ["Chapter30Observability"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        .testTarget(
            name: "Chapter30ObservabilityTests",
            dependencies: [
                "Chapter30Observability",
                .product(name: "FieldNotesAgentLoop", package: "Chapter20AgentLoop"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
