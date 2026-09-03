import SwiftUI

struct NotesListView: View {
    let state: NotesScreenState
    let onOpen: (NoteSummary) -> Void
    let onRetry: () -> Void
    let onCreate: () -> Void

    var body: some View {
        content
            .accessibilityIdentifier("notes-list")
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Note", systemImage: "square.and.pencil", action: onCreate)
                        .accessibilityIdentifier("new-note")
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            FieldNotesMessageView(
                title: "Loading Notes",
                message: "FieldNotes is gathering your notes.",
                systemImage: "note.text",
                showsProgress: true
            )
        case .empty:
            FieldNotesMessageView(
                title: "No Notes Yet",
                message: "Create a note to begin your field record.",
                systemImage: "note.text.badge.plus",
                actionTitle: "Create Note",
                onAction: onCreate
            )
        case .error(let message):
            FieldNotesMessageView(
                title: "Notes Unavailable",
                message: message,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Try Again",
                onAction: onRetry
            )
        case .loaded(let notes):
            noteList(notes)
        case .partial(let notes, let message):
            VStack(spacing: 0) {
                Text(message)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.yellow.opacity(0.18))
                    .accessibilityLabel("Some notes are unavailable. \(message)")
                noteList(notes)
            }
        }
    }

    private func noteList(_ notes: [NoteSummary]) -> some View {
        List(notes) { note in
            Button {
                onOpen(note)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.title)
                        .font(.headline)
                    Text(note.excerpt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(note.title)
            .accessibilityValue(note.excerpt)
            .accessibilityHint("Opens note details")
            .accessibilityIdentifier("note-row-\(note.id.uuidString)")
        }
        .listStyle(.plain)
    }
}
