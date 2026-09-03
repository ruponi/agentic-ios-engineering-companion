import Foundation
import FieldNotesAgentLoop

public enum MatrixCellStatus: String, Sendable, Codable, Equatable {
    case filled
    case verifyRun
}

public struct EvaluationMatrixCell: Sendable, Codable {
    public let promptVersion: String
    public let modelRoute: String
    public let operatingSystem: String
    public let localeIdentifier: String
    public let status: MatrixCellStatus

    public init(
        runRecord: ModelRunRecord,
        modelRoute: String,
        locale: Locale,
        status: MatrixCellStatus
    ) {
        promptVersion = runRecord.promptVersion.rawValue
        self.modelRoute = modelRoute
        operatingSystem = runRecord.operatingSystemVersion
        localeIdentifier = locale.identifier
        self.status = status
    }
}

public enum EvaluationMatrix {
    public static func verifiedFixtureCell() -> EvaluationMatrixCell {
        let record = ModelRunRecord(
            promptVersion: .packingBriefV1,
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            providerIdentifier: "scripted-fixture",
            modelIdentifier: "successful-model"
        )
        return EvaluationMatrixCell(
            runRecord: record,
            modelRoute: "scripted-fixture",
            locale: Locale(identifier: "en_US_POSIX"),
            status: .filled
        )
    }
}
