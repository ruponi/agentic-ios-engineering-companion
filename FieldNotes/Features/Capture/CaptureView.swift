import SwiftUI

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let library: FieldNotesLibrary
    @State private var model: CaptureModel

    init(store: any CaptureService, library: FieldNotesLibrary) {
        self.library = library
        _model = State(initialValue: CaptureModel(service: store))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $model.text)
                        .frame(minHeight: 180)
                        .accessibilityLabel("Note text")
                        .accessibilityHint("Enter the text of your field note")
                        .accessibilityIdentifier("note-text")
                } header: {
                    Text("Observation")
                } footer: {
                    if let message = model.validationMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("validation-message")
                    } else if let message = model.failureMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("save-failure")
                    }
                }
            }
            .navigationTitle("New Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            guard await model.save() else { return }
                            await library.reload()
                            dismiss()
                        }
                    }
                    .disabled(!model.canSave)
                    .accessibilityIdentifier("save-note")
                }
            }
        }
    }
}

#Preview("Capture") {
    let store = InMemoryNoteStore()
    CaptureView(store: store, library: FieldNotesLibrary(store: store))
}
