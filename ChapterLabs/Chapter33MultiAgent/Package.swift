// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Chapter33MultiAgent",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BeyondOneAgent", targets: ["BeyondOneAgent"]),
        .executable(name: "MultiAgentTrace", targets: ["MultiAgentTrace"])
    ],
    dependencies: [.package(path: "../Chapter20AgentLoop")],
    targets: [
        .target(
            name: "BeyondOneAgent",
            dependencies: [
                .product(name: "FieldNotesAgentLoop", package: "Chapter20AgentLoop")
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        .executableTarget(
            name: "MultiAgentTrace",
            dependencies: [
                "BeyondOneAgent",
                .product(name: "FieldNotesAgentLoop", package: "Chapter20AgentLoop")
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        .testTarget(
            name: "BeyondOneAgentTests",
            dependencies: [
                "BeyondOneAgent",
                .product(name: "FieldNotesAgentLoop", package: "Chapter20AgentLoop")
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        )
    ],
    swiftLanguageModes: [.v6]
)
