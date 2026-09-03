public enum AgentSurface: String, Sendable, CaseIterable {
    case watchVoiceOnly
    case iPadMultipleWindows
    case macUserSelectedFile
    case spatialScene
}

public enum PlatformAgentConstraint {
    public static func consequence(for surface: AgentSurface) -> String {
        switch surface {
        case .watchVoiceOnly:
            "Transfer exact-action review to a screen or paired device; do not offer approval."
        case .iPadMultipleWindows:
            "Keep each pending action bound to the scene that displayed its exact fields."
        case .macUserSelectedFile:
            "Use only person-selected security-scoped URLs and release access after the read."
        case .spatialScene:
            "Keep consequential review in a bounded window; immersion grants no extra authority."
        }
    }
}
