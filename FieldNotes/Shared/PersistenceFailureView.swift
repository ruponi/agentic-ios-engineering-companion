import SwiftUI

struct PersistenceFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Notes Unavailable", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(message)
        }
        .accessibilityIdentifier("persistence-failure")
    }
}

#Preview("Migration failure") {
    PersistenceFailureView(
        message: "Your notes could not be opened. FieldNotes did not create an empty replacement."
    )
}
