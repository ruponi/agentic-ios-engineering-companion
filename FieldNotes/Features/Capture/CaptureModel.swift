import Foundation
import Observation

struct CaptureDraft: Equatable, Sendable {
    let text: String
}

protocol CaptureService: Sendable {
    func save(_ draft: CaptureDraft) async throws
}

@MainActor
@Observable
final class CaptureModel {
    var text = ""
    private(set) var isSaving = false
    private(set) var validationMessage: String?
    private(set) var failureMessage: String?
    private let service: any CaptureService

    init(service: any CaptureService) {
        self.service = service
    }

    var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    func save() async -> Bool {
        validationMessage = nil
        failureMessage = nil

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "A note needs visible text."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await service.save(CaptureDraft(text: text))
            text = ""
            return true
        } catch {
            failureMessage = "The note could not be saved. Your text is still here."
            return false
        }
    }
}
