import FieldNotesAgentLoop
import SwiftUI

struct VoiceInteractionView: View {
    let pending: PendingAction
    var onTransferToScreen: () -> Void
    var onDecline: () -> Void

    private var readback: VoiceReadback { VoiceReadback(pending: pending) }

    var body: some View {
        VStack(spacing: 20) {
            FieldNotesMessageView(
                title: "Voice Review Has Limits",
                message: limitation,
                systemImage: "waveform.badge.exclamationmark"
            )
            .accessibilityIdentifier("voice-interaction")

            ScrollView {
                Text(readback.transcript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            Button("Review Exact Action on Screen", action: onTransferToScreen)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("voice-transfer")
            Button("Decline", role: .cancel, action: onDecline)
        }
        .padding()
    }

    private var limitation: String {
        pending.effect == .consequential
            ? "Consequential changes are unavailable in voice-only mode. Transfer to the screen."
            : "Listen to every exact field, or transfer to the screen before deciding."
    }
}
