import Foundation

public struct ExtractedMedia: Sendable, Codable, Equatable {
    public let sourceID: UUID
    public let text: String

    public init(sourceID: UUID, text: String) {
        self.sourceID = sourceID
        self.text = text
    }
}

public typealias MediaExtractionEnvelope = ToolResultEnvelope<ExtractedMedia>

public protocol MediaExtracting: Sendable {
    func extractText(from media: Data) async throws -> String
}

public struct OnDeviceMediaPipeline<Extractor: MediaExtracting>: Sendable {
    private let extractor: Extractor

    public init(extractor: Extractor) { self.extractor = extractor }

    public func ingest(media: Data, sourceID: UUID) async throws -> MediaExtractionEnvelope {
        let text = try await extractor.extractText(from: media)
        return ToolResultEnvelope(
            sourceTool: "onDeviceMediaExtraction",
            data: ExtractedMedia(sourceID: sourceID, text: text)
        )
    }
}

public struct MinimizedMediaContext: Sendable, Codable, Equatable {
    public let sourceID: UUID
    public let extractedExcerpt: String

    public init(sourceID: UUID, extractedExcerpt: String) {
        self.sourceID = sourceID
        self.extractedExcerpt = extractedExcerpt
    }
}

public struct MediaCloudMinimizer: Sendable {
    public let maximumCharacters: Int

    public init(maximumCharacters: Int) {
        self.maximumCharacters = maximumCharacters
    }

    public func minimize(_ envelope: MediaExtractionEnvelope) -> MinimizedMediaContext {
        MinimizedMediaContext(
            sourceID: envelope.data.sourceID,
            extractedExcerpt: String(envelope.data.text.prefix(max(0, maximumCharacters)))
        )
    }
}

public protocol SpeechPlayback: Sendable {
    func speak(_ text: String) async throws
    func stop() async
}

public enum SpokenOutputOutcome: Sendable, Equatable {
    case completed
    case declined
}

public actor SpeechOutputSession {
    private let playback: any SpeechPlayback

    public init(playback: any SpeechPlayback) { self.playback = playback }

    public func stream(_ chunks: [String]) async -> SpokenOutputOutcome {
        do {
            for chunk in chunks {
                try Task.checkCancellation()
                try await playback.speak(chunk)
            }
            return .completed
        } catch {
            return .declined
        }
    }

    public func bargeIn() async {
        await playback.stop()
    }
}

public struct VoiceReadback: Sendable, Equatable {
    public let fields: [String]
    public var transcript: String { fields.joined(separator: ". ") }

    public init(pending: PendingAction) {
        var values = ["Effect: \(pending.effect.rawValue)"]
        switch pending.action {
        case .savePackingBrief(let arguments):
            values.append("Tool: savePackingBrief")
            values.append("Title: \(arguments.title)")
            values += arguments.items.enumerated().map { "Item \($0.offset + 1): \($0.element)" }
            values.append("Source notes: \(arguments.sourceNoteIDs.map(\.uuidString).joined(separator: ", "))")
        case .tagNote(let arguments):
            values += ["Tool: tagNote", "Note ID: \(arguments.noteID)", "Tag: \(arguments.tag)"]
        case .deleteNote(let arguments):
            values += ["Tool: deleteNote", "Note ID: \(arguments.noteID)"]
        }
        values.append("Idempotency key: \(pending.idempotencyKey)")
        fields = values
    }
}

public enum VoiceApprovalFailure: Error, Sendable, Equatable {
    case consequentialEffectUnavailable
    case readbackNotCompleted
    case transcriptMismatch
    case explicitConfirmationRequired
    case alreadyDeclined
}

public actor VoiceApprovalSession {
    public static let explicitConfirmationToken = "CONFIRM EXACT CHANGE"

    private let pending: PendingAction
    private let readback: VoiceReadback
    private var completedReadback = false
    private var declined = false
    private var events: [TraceEvent]

    public init(pending: PendingAction) {
        self.pending = pending
        self.readback = VoiceReadback(pending: pending)
        self.events = [TraceEvent("OBSERVE", "voice-only pending=\(pending.id)")]
    }

    public func beginReadback() throws -> VoiceReadback {
        guard !declined else { throw VoiceApprovalFailure.alreadyDeclined }
        guard pending.effect != .consequential else {
            decline("consequential-effect-unavailable")
            throw VoiceApprovalFailure.consequentialEffectUnavailable
        }
        events.append(TraceEvent("DECIDE", "readback=verbatim-fields"))
        return readback
    }

    public func recordCompletedReadback(transcript: String) throws {
        guard !declined else { throw VoiceApprovalFailure.alreadyDeclined }
        guard transcript == readback.transcript else {
            decline("transcript-mismatch")
            throw VoiceApprovalFailure.transcriptMismatch
        }
        completedReadback = true
        events.append(TraceEvent("VERIFY", "verbatim-readback=complete"))
    }

    public func interruptReadback() {
        guard !declined else { return }
        decline("readback-interrupted")
    }

    public func confirm(spokenToken: String) throws -> ApprovedAction {
        guard !declined else { throw VoiceApprovalFailure.alreadyDeclined }
        guard completedReadback else {
            decline("readback-not-completed")
            throw VoiceApprovalFailure.readbackNotCompleted
        }
        guard spokenToken == Self.explicitConfirmationToken else {
            decline("explicit-confirmation-missing")
            throw VoiceApprovalFailure.explicitConfirmationRequired
        }
        events.append(TraceEvent("ACT", "approval-minted pending=\(pending.id)"))
        events.append(TraceEvent("STOP", "confirmed"))
        return try PendingActionAmendment(original: pending).approve(pendingID: pending.id)
    }

    public func trace() -> [TraceEvent] { events }

    private func decline(_ reason: String) {
        declined = true
        completedReadback = false
        events.append(TraceEvent("STOP", "declined reason=\(reason)"))
    }
}
