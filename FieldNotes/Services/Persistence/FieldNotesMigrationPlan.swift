import Foundation
import SwiftData

/// Lists every supported schema in order. The V1-to-V2 change is purely
/// additive and therefore qualifies as a lightweight stage.
///
/// Before shipping, rerun the seeded migration suite against every supported OS
/// version that may perform the upgrade. SwiftData migration behaviour is
/// version-sensitive.
enum FieldNotesMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FieldNotesSchemaV1.self, FieldNotesSchemaV2.self, FieldNotesSchemaV3.self]
    }

    static var stages: [MigrationStage] { [v1toV2, v2toV3] }

    static let v1toV2 = MigrationStage.lightweight(
        fromVersion: FieldNotesSchemaV1.self,
        toVersion: FieldNotesSchemaV2.self
    )

    static let v2toV3 = MigrationStage.lightweight(
        fromVersion: FieldNotesSchemaV2.self,
        toVersion: FieldNotesSchemaV3.self
    )
}
