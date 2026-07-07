import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class AEDDatabase {
    private let url: URL
    private var database: OpaquePointer?
    private let dateFormatter = ISO8601DateFormatter()
    private let recordColumns: Set<String>

    init(url: URL) throws {
        self.url = url
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unable to open database"
            if let handle { sqlite3_close(handle) }
            throw AEDDatabaseError.openFailed(message)
        }
        do {
            recordColumns = try Self.tableColumnNames(handle: handle, table: "aed_records")
        } catch {
            sqlite3_close(handle)
            throw error
        }
        database = handle
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func records(near coordinate: Coordinate, radiusMeters: Double) throws -> [AEDRecord] {
        let latDelta = radiusMeters / 111_320
        let cosLatitude = max(0.01, cos(coordinate.latitude * .pi / 180))
        let lonDelta = radiusMeters / (111_320 * cosLatitude)

        let sql = """
        SELECT \(recordSelectList)
        FROM aed_records
        WHERE latitude BETWEEN ? AND ?
          AND longitude BETWEEN ? AND ?
        """

        return try queryRecords(
            sql: sql,
            bind: { statement in
                sqlite3_bind_double(statement, 1, coordinate.latitude - latDelta)
                sqlite3_bind_double(statement, 2, coordinate.latitude + latDelta)
                sqlite3_bind_double(statement, 3, coordinate.longitude - lonDelta)
                sqlite3_bind_double(statement, 4, coordinate.longitude + lonDelta)
            }
        )
    }

    func allRecords(limit: Int?) throws -> [AEDRecord] {
        let sql: String
        if let limit {
            sql = """
            SELECT \(recordSelectList)
            FROM aed_records
            ORDER BY name COLLATE NOCASE
            LIMIT \(max(0, limit))
            """
        } else {
            sql = """
            SELECT \(recordSelectList)
            FROM aed_records
            ORDER BY name COLLATE NOCASE
            """
        }
        return try queryRecords(sql: sql, bind: { _ in })
    }

    func metadata() throws -> AEDSourceMetadata {
        let values = try metadataValues()
        return AEDSourceMetadata(
            datasetID: values["dataset_id"],
            regionID: values["region_id"],
            version: values["version"],
            sourceName: values["source_name"] ?? values["source"] ?? "Unknown source",
            sourceUpdatedAt: parseDate(values["source_updated_at"] ?? values["source_updated_at_max"]),
            attributionText: values["attribution"],
            licence: values["licence"] ?? values["license"],
            importedAt: parseDate(values["imported_at"]),
            newestSourceUpdatedAt: parseDate(values["source_updated_at_max"]),
            recordCount: Int(values["record_count"] ?? "0") ?? 0,
            reliability: values["reliability"]
        )
    }

    func coordinateBounds() throws -> AEDRegionBounds? {
        guard let database else { throw AEDDatabaseError.closed }
        let sql = "SELECT MIN(latitude), MAX(latitude), MIN(longitude), MAX(longitude) FROM aed_records"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw AEDDatabaseError.prepareFailed(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW,
              sqlite3_column_type(statement, 0) != SQLITE_NULL,
              sqlite3_column_type(statement, 1) != SQLITE_NULL,
              sqlite3_column_type(statement, 2) != SQLITE_NULL,
              sqlite3_column_type(statement, 3) != SQLITE_NULL
        else {
            return nil
        }

        return AEDRegionBounds(
            minLatitude: sqlite3_column_double(statement, 0),
            maxLatitude: sqlite3_column_double(statement, 1),
            minLongitude: sqlite3_column_double(statement, 2),
            maxLongitude: sqlite3_column_double(statement, 3)
        )
    }

    func validateForImport(requiresLicencePerRecord: Bool = true) throws -> AEDDatabaseValidationResult {
        guard let database else { throw AEDDatabaseError.closed }
        var errors: [String] = []

        if requiresLicencePerRecord && !recordColumns.contains("licence_text") {
            errors.append("aed_records.licence_text is required for imported AED databases.")
        }

        let recordCount = try scalarInt("SELECT COUNT(*) FROM aed_records")
        if recordCount == 0 {
            errors.append("AED snapshot contains no records.")
        }

        let distinctIDCount = try scalarInt("SELECT COUNT(DISTINCT id) FROM aed_records")
        if distinctIDCount != recordCount {
            errors.append("AED snapshot contains duplicate record IDs.")
        }

        let invalidCoordinateCount = try scalarInt(
            "SELECT COUNT(*) FROM aed_records WHERE latitude < -90 OR latitude > 90 OR longitude < -180 OR longitude > 180"
        )
        if invalidCoordinateCount > 0 {
            errors.append("AED snapshot contains invalid coordinates.")
        }

        let missingRequiredCount = try scalarInt(
            """
            SELECT COUNT(*) FROM aed_records
            WHERE id IS NULL OR TRIM(id) = ''
               OR source IS NULL OR TRIM(source) = ''
               OR imported_at IS NULL OR TRIM(imported_at) = ''
               OR access_type IS NULL OR TRIM(access_type) = ''
               OR confidence IS NULL OR TRIM(confidence) = ''
            """
        )
        if missingRequiredCount > 0 {
            errors.append("AED snapshot is missing required fields.")
        }

        let validAccessValues = AccessType.allCases.map { "'\($0.rawValue)'" }.joined(separator: ",")
        let invalidAccessCount = try scalarInt("SELECT COUNT(*) FROM aed_records WHERE access_type NOT IN (\(validAccessValues))")
        if invalidAccessCount > 0 {
            errors.append("AED snapshot contains unsupported access statuses.")
        }

        if requiresLicencePerRecord && recordColumns.contains("licence_text") {
            let missingLicenceCount = try scalarInt(
                "SELECT COUNT(*) FROM aed_records WHERE licence_text IS NULL OR TRIM(licence_text) = '' OR LOWER(TRIM(licence_text)) = 'unknown'"
            )
            if missingLicenceCount > 0 {
                errors.append("AED snapshot contains records without redistributable licence metadata.")
            }
        }

        _ = database
        return AEDDatabaseValidationResult(errors: errors)
    }

    static func writeMetadata(_ values: [String: String], to url: URL) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unable to open database"
            if let handle { sqlite3_close(handle) }
            throw AEDDatabaseError.openFailed(message)
        }
        defer { sqlite3_close(handle) }

        guard sqlite3_exec(handle, "CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)", nil, nil, nil) == SQLITE_OK else {
            throw AEDDatabaseError.prepareFailed(lastErrorMessage(handle: handle))
        }

        let sql = "INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw AEDDatabaseError.prepareFailed(lastErrorMessage(handle: handle))
        }
        defer { sqlite3_finalize(statement) }

        for (key, value) in values {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, value, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw AEDDatabaseError.prepareFailed(lastErrorMessage(handle: handle))
            }
        }
    }

    private func queryRecords(sql: String, bind: (OpaquePointer?) -> Void) throws -> [AEDRecord] {
        guard let database else { throw AEDDatabaseError.closed }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw AEDDatabaseError.prepareFailed(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        bind(statement)

        var records: [AEDRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            records.append(try record(from: statement))
        }
        return records
    }

    private func record(from statement: OpaquePointer?) throws -> AEDRecord {
        guard let id = text(statement, 0),
              let source = text(statement, 1),
              let importedAt = parseDate(text(statement, 4)),
              let accessRaw = text(statement, 11),
              let accessType = AccessType(rawValue: accessRaw),
              let confidenceRaw = text(statement, 18),
              let confidence = AEDConfidence(rawValue: confidenceRaw)
        else {
            throw AEDDatabaseError.invalidRow
        }

        return AEDRecord(
            id: id,
            source: source,
            sourceRecordID: text(statement, 2),
            sourceUpdatedAt: parseDate(text(statement, 3)),
            importedAt: importedAt,
            latitude: sqlite3_column_double(statement, 5),
            longitude: sqlite3_column_double(statement, 6),
            name: text(statement, 7),
            address: text(statement, 8),
            locationDescription: text(statement, 9),
            indoorLocation: text(statement, 10),
            accessType: accessType,
            openingHoursRaw: text(statement, 12),
            isCurrentlyLikelyAccessible: nullableBool(statement, 13),
            accessInstructions: text(statement, 14),
            cabinetCodeInstruction: text(statement, 15),
            phone: text(statement, 16),
            lastVerifiedAt: parseDate(text(statement, 17)),
            confidence: confidence,
            notes: text(statement, 19),
            attributionText: text(statement, 20),
            licence: text(statement, 21)
        )
    }

    private func metadataValues() throws -> [String: String] {
        guard let database else { throw AEDDatabaseError.closed }
        let sql = "SELECT key, value FROM metadata"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw AEDDatabaseError.prepareFailed(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        var values: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let key = text(statement, 0), let value = text(statement, 1) else { continue }
            values[key] = value
        }
        return values
    }

    private func text(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let pointer = sqlite3_column_text(statement, index)
        else {
            return nil
        }
        let value = String(cString: pointer)
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
    }

    private func scalarInt(_ sql: String) throws -> Int {
        guard let database else { throw AEDDatabaseError.closed }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw AEDDatabaseError.prepareFailed(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func nullableBool(_ statement: OpaquePointer?, _ index: Int32) -> Bool? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_int(statement, index) != 0
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return dateFormatter.date(from: value)
    }

    private var lastErrorMessage: String {
        guard let database, let message = sqlite3_errmsg(database) else { return "Unknown SQLite error" }
        return String(cString: message)
    }

    private var recordSelectList: String {
        let licenceExpression = recordColumns.contains("licence_text") ? "licence_text" : "NULL AS licence_text"
        return """
        id, source, source_record_id, source_updated_at, imported_at,
               latitude, longitude, name, address, location_description,
               indoor_location, access_type, opening_hours_raw,
               is_currently_likely_accessible, access_instructions,
               cabinet_code_instruction, phone, last_verified_at,
               confidence, notes, attribution_text, \(licenceExpression)
        """
    }

    private static func tableColumnNames(handle: OpaquePointer?, table: String) throws -> Set<String> {
        let escapedTable = table.replacingOccurrences(of: "'", with: "''")
        let sql = "PRAGMA table_info('\(escapedTable)')"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw AEDDatabaseError.prepareFailed(lastErrorMessage(handle: handle))
        }
        defer { sqlite3_finalize(statement) }

        var columns: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let pointer = sqlite3_column_text(statement, 1) {
                columns.insert(String(cString: pointer))
            }
        }
        return columns
    }

    private static func lastErrorMessage(handle: OpaquePointer?) -> String {
        guard let handle, let message = sqlite3_errmsg(handle) else { return "Unknown SQLite error" }
        return String(cString: message)
    }
}

struct AEDDatabaseValidationResult: Equatable {
    var errors: [String]

    var isValid: Bool {
        errors.isEmpty
    }
}

enum AEDDatabaseError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case invalidRow
    case closed

    var errorDescription: String? {
        switch self {
        case .openFailed(let message): return "Could not open AED database: \(message)"
        case .prepareFailed(let message): return "Could not prepare AED database query: \(message)"
        case .invalidRow: return "AED database contains an invalid row."
        case .closed: return "AED database is closed."
        }
    }
}
