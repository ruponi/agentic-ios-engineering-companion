import SwiftUI

enum IntelligenceFallbackState: String, Equatable {
    case deviceIneligible = "device-ineligible"
    case modelNotReady = "model-not-ready"
    case frameworkUnavailable = "framework-unavailable"

    var title: LocalizedStringKey {
        switch self {
        case .deviceIneligible:
            "Smart Briefs Aren’t Available"
        case .modelNotReady:
            "Smart Briefs Are Getting Ready"
        case .frameworkUnavailable:
            "Smart Briefs Need a Newer System"
        }
    }

    var message: String {
        switch self {
        case .deviceIneligible:
            "This device can’t run the on-device model. Your notes, search, and deterministic packing brief still work."
        case .modelNotReady:
            "The on-device model may still be downloading. Your notes remain available while FieldNotes waits."
        case .frameworkUnavailable:
            "This system doesn’t include the model framework. Your notes, search, and deterministic packing brief still work."
        }
    }
}

struct IntelligenceFallbackView: View {
    let state: IntelligenceFallbackState
    var onRetry: () -> Void = {}

    var body: some View {
        FieldNotesMessageView(
            title: state.title,
            message: state.message,
            systemImage: "sparkles",
            showsProgress: state == .modelNotReady,
            actionTitle: state == .modelNotReady ? "Retry" : nil,
            onAction: onRetry
        )
        .accessibilityIdentifier("intelligence-fallback")
    }
}

#Preview("Device ineligible") {
    IntelligenceFallbackView(state: .deviceIneligible)
}

#Preview("Model not ready") {
    IntelligenceFallbackView(state: .modelNotReady)
}

#Preview("Framework unavailable") {
    IntelligenceFallbackView(state: .frameworkUnavailable)
}
