// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Chapter29Evaluation",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Chapter29Evaluation", targets: ["Chapter29Evaluation"]),
        .executable(name: "EvaluationRunner", targets: ["EvaluationRunner"]),
    ],
    dependencies: [
        .package(path: "../Chapter20AgentLoop"),
    ],
    targets: [
        .target(
            name: "Chapter29Evaluation",
            dependencies: [
                .product(name: "FieldNotesAgentLoop", package: "Chapter20AgentLoop"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        .executableTarget(
            name: "EvaluationRunner",
            dependencies: ["Chapter29Evaluation"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        .testTarget(
            name: "Chapter29EvaluationTests",
            dependencies: [
                "Chapter29Evaluation",
                .product(name: "FieldNotesAgentLoop", package: "Chapter20AgentLoop"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
