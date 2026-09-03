import SwiftUI

struct FieldNotesMessageView: View {
    let title: LocalizedStringKey
    let message: String
    let systemImage: String
    var showsProgress = false
    var actionTitle: LocalizedStringKey?
    var onAction: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if showsProgress {
                    ProgressView()
                } else {
                    Image(systemName: systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(.title2.bold())

                Text(verbatim: message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let actionTitle {
                    Button(actionTitle, action: onAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
