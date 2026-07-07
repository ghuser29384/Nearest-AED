import Foundation

enum AccessType: String, Codable, CaseIterable {
    case public24h
    case publicLimitedHours
    case restricted
    case lockedCabinet
    case unknown

    var displayName: String {
        switch self {
        case .public24h: return "Public access, likely available now"
        case .publicLimitedHours: return "Public access, limited hours"
        case .restricted: return "Restricted access"
        case .lockedCabinet: return "Locked cabinet"
        case .unknown: return "Access unknown"
        }
    }
}

enum AEDConfidence: String, Codable, CaseIterable {
    case high
    case medium
    case low
    case unknown

    var sortRank: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        case .unknown: return 3
        }
    }
}

struct AEDRecord: Identifiable, Codable, Equatable {
    var id: String
    var source: String
    var sourceRecordID: String?
    var sourceUpdatedAt: Date?
    var importedAt: Date
    var latitude: Double
    var longitude: Double
    var name: String?
    var address: String?
    var locationDescription: String?
    var indoorLocation: String?
    var accessType: AccessType
    var openingHoursRaw: String?
    var isCurrentlyLikelyAccessible: Bool?
    var accessInstructions: String?
    var cabinetCodeInstruction: String?
    var phone: String?
    var lastVerifiedAt: Date?
    var confidence: AEDConfidence
    var notes: String?
    var attributionText: String?
    var licence: String? = nil

    var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }

    var displayTitle: String {
        name?.nilIfBlank ?? address?.nilIfBlank ?? "AED"
    }

    var displaySubtitle: String {
        [locationDescription?.nilIfBlank, address?.nilIfBlank]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

struct AEDRegionBounds: Codable, Equatable {
    var minLatitude: Double
    var maxLatitude: Double
    var minLongitude: Double
    var maxLongitude: Double

    func contains(_ coordinate: Coordinate) -> Bool {
        coordinate.latitude >= minLatitude
            && coordinate.latitude <= maxLatitude
            && coordinate.longitude >= minLongitude
            && coordinate.longitude <= maxLongitude
    }
}

struct AEDSourceMetadata: Equatable {
    var datasetID: String? = nil
    var regionID: String? = nil
    var version: String? = nil
    var sourceName: String
    var sourceUpdatedAt: Date? = nil
    var attributionText: String?
    var licence: String? = nil
    var importedAt: Date?
    var newestSourceUpdatedAt: Date?
    var recordCount: Int
    var reliability: String?

    func warnings(now: Date = Date(), staleAfterDays: Int = 365) -> [String] {
        if sourceName.localizedCaseInsensitiveContains("synthetic") {
            return ["Bundled AED data is synthetic development seed data. Import a permitted real AED dataset before field use."]
        }

        var warnings: [String] = []
        if let reliability {
            if reliability.localizedCaseInsensitiveContains("unknown") {
                warnings.append("AED source reliability is unknown. Verify with emergency services where possible.")
            } else if reliability.localizedCaseInsensitiveContains("low") {
                warnings.append("AED source reliability is low. Verify with emergency services where possible.")
            }
        } else {
            warnings.append("AED source reliability is unknown. Verify with emergency services where possible.")
        }

        if licence?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            warnings.append("AED source licence is unknown. Do not redistribute this data until the licence permits app/database use.")
        } else if licence?.localizedCaseInsensitiveContains("unknown") == true {
            warnings.append("AED source licence is unknown. Do not redistribute this data until the licence permits app/database use.")
        }

        if let newestSourceUpdatedAt {
            let threshold = TimeInterval(staleAfterDays * 24 * 60 * 60)
            if now.timeIntervalSince(newestSourceUpdatedAt) > threshold {
                warnings.append("AED data is older than \(staleAfterDays) days and may be outdated.")
            }
        } else {
            warnings.append("AED data source update date is unknown.")
        }

        return warnings
    }

    func warning(now: Date = Date(), staleAfterDays: Int = 365) -> String? {
        warnings(now: now, staleAfterDays: staleAfterDays).first
    }
}

struct AEDSearchResult: Identifiable, Equatable {
    var id: String { record.id }
    var record: AEDRecord
    var distanceMeters: Double
    var bearingDegrees: Double
    var directionText: String

    var readout: String {
        let place = record.displayTitle
        let location = record.locationDescription?.nilIfBlank ?? record.address?.nilIfBlank ?? "location details unavailable"
        let access = record.accessType.displayName.lowercased()
        return "Nearest AED: \(DistanceBearing.formattedDistance(distanceMeters)) \(directionText). \(place), \(location). \(access)."
    }
}

protocol AEDRepositoryProtocol {
    func records(near coordinate: Coordinate, radiusMeters: Double) throws -> [AEDRecord]
    func allRecords(limit: Int?) throws -> [AEDRecord]
    func metadata() throws -> AEDSourceMetadata
}

final class AEDRepository: AEDRepositoryProtocol {
    private let database: AEDDatabase

    init(database: AEDDatabase) {
        self.database = database
    }

    convenience init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "aed_seed", withExtension: "sqlite") else {
            throw AEDRepositoryError.missingBundledDatabase
        }
        try self.init(database: AEDDatabase(url: url))
    }

    func records(near coordinate: Coordinate, radiusMeters: Double) throws -> [AEDRecord] {
        try database.records(near: coordinate, radiusMeters: radiusMeters)
    }

    func allRecords(limit: Int?) throws -> [AEDRecord] {
        try database.allRecords(limit: limit)
    }

    func metadata() throws -> AEDSourceMetadata {
        try database.metadata()
    }
}

final class CompositeAEDRepository: AEDRepositoryProtocol {
    private let databases: [AEDDatabase]

    init(databaseURLs: [URL]) throws {
        databases = try databaseURLs.map { try AEDDatabase(url: $0) }
    }

    func records(near coordinate: Coordinate, radiusMeters: Double) throws -> [AEDRecord] {
        try databases.flatMap { try $0.records(near: coordinate, radiusMeters: radiusMeters) }
    }

    func allRecords(limit: Int?) throws -> [AEDRecord] {
        let records = try databases.flatMap { try $0.allRecords(limit: limit) }
            .sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        guard let limit else { return records }
        return Array(records.prefix(limit))
    }

    func metadata() throws -> AEDSourceMetadata {
        let metadata = try databases.map { try $0.metadata() }
        let newestSourceUpdatedAt = metadata.compactMap(\.newestSourceUpdatedAt).max()
        let importedAt = metadata.compactMap(\.importedAt).max()
        let sourceNames = metadata.map(\.sourceName).uniqued().joined(separator: ", ")
        let licences = metadata.compactMap(\.licence).filter { !$0.isEmpty }.uniqued().joined(separator: ", ")
        let attribution = metadata.compactMap(\.attributionText).filter { !$0.isEmpty }.uniqued().joined(separator: "\n")
        let reliabilities = metadata.compactMap(\.reliability)
        let reliability: String?
        if reliabilities.contains(where: { $0.localizedCaseInsensitiveContains("low") }) {
            reliability = "low"
        } else if reliabilities.contains(where: { $0.localizedCaseInsensitiveContains("unknown") }) || reliabilities.count != metadata.count {
            reliability = "unknown"
        } else {
            reliability = reliabilities.first
        }

        return AEDSourceMetadata(
            sourceName: sourceNames.isEmpty ? "No installed AED data" : sourceNames,
            attributionText: attribution.isEmpty ? nil : attribution,
            licence: licences.isEmpty ? nil : licences,
            importedAt: importedAt,
            newestSourceUpdatedAt: newestSourceUpdatedAt,
            recordCount: metadata.reduce(0) { $0 + $1.recordCount },
            reliability: reliability
        )
    }
}

enum AEDRepositoryError: Error, LocalizedError {
    case missingBundledDatabase

    var errorDescription: String? {
        switch self {
        case .missingBundledDatabase:
            return "Bundled AED database is missing."
        }
    }
}

struct StaticAEDRepository: AEDRepositoryProtocol {
    var records: [AEDRecord]
    var sourceMetadata: AEDSourceMetadata

    func records(near coordinate: Coordinate, radiusMeters: Double) throws -> [AEDRecord] {
        records.filter {
            DistanceBearing.distanceMeters(from: coordinate, to: $0.coordinate) <= radiusMeters
        }
    }

    func allRecords(limit: Int?) throws -> [AEDRecord] {
        guard let limit else { return records }
        return Array(records.prefix(limit))
    }

    func metadata() throws -> AEDSourceMetadata {
        sourceMetadata
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []
        return filter { seen.insert($0).inserted }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
