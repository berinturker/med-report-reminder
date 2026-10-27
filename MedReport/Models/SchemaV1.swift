import Foundation
import SwiftData

/// The first data schema (spec 6.1). Later schemas add a migration stage to `MedReportMigrationPlan`.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Report.self, Medication.self] }
}

enum MedReportMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

typealias Report = SchemaV1.Report
typealias Medication = SchemaV1.Medication
