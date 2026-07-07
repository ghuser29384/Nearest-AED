import Foundation

struct AEDSearchService {
    var repository: AEDRepositoryProtocol
    var defaultRadiusMeters: Double = 50_000

    func nearestAEDs(
        from coordinate: Coordinate,
        headingDegrees: Double? = nil,
        showAll: Bool = false,
        limit: Int = 10,
        now: Date = Date()
    ) throws -> [AEDSearchResult] {
        let candidates = try repository.records(near: coordinate, radiusMeters: defaultRadiusMeters)
        let visible = showAll ? candidates : candidates.filter { isVisibleByDefault($0, now: now) }

        return visible.compactMap { record in
            let distance = DistanceBearing.distanceMeters(from: coordinate, to: record.coordinate)
            guard distance <= defaultRadiusMeters else { return nil }
            let bearing = DistanceBearing.bearingDegrees(from: coordinate, to: record.coordinate)
            return AEDSearchResult(
                record: record,
                distanceMeters: distance,
                bearingDegrees: DistanceBearing.relativeBearingDegrees(bearing: bearing, heading: headingDegrees),
                directionText: DistanceBearing.compassDirection(for: bearing)
            )
        }
        .sorted { lhs, rhs in
            let leftRank = accessibilityRank(lhs.record, now: now)
            let rightRank = accessibilityRank(rhs.record, now: now)
            if leftRank != rightRank { return leftRank < rightRank }
            if lhs.distanceMeters != rhs.distanceMeters { return lhs.distanceMeters < rhs.distanceMeters }
            if lhs.record.confidence.sortRank != rhs.record.confidence.sortRank {
                return lhs.record.confidence.sortRank < rhs.record.confidence.sortRank
            }
            return (lhs.record.lastVerifiedAt ?? .distantPast) > (rhs.record.lastVerifiedAt ?? .distantPast)
        }
        .prefix(limit)
        .map { $0 }
    }

    func fallbackRecords(limit: Int = 50) throws -> [AEDRecord] {
        try repository.allRecords(limit: limit)
            .sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
    }

    func metadataWarning(now: Date = Date()) -> String? {
        try? repository.metadata().warning(now: now)
    }

    func metadata() -> AEDSourceMetadata? {
        try? repository.metadata()
    }

    private func isVisibleByDefault(_ record: AEDRecord, now: Date) -> Bool {
        switch record.accessType {
        case .restricted:
            return record.isCurrentlyLikelyAccessible == true
        case .lockedCabinet:
            return record.isCurrentlyLikelyAccessible == true || record.cabinetCodeInstruction != nil
        case .public24h, .publicLimitedHours, .unknown:
            return true
        }
    }

    private func accessibilityRank(_ record: AEDRecord, now: Date) -> Int {
        if record.isCurrentlyLikelyAccessible == true { return 0 }
        if record.isCurrentlyLikelyAccessible == false { return 3 }

        switch record.accessType {
        case .public24h:
            return 0
        case .publicLimitedHours:
            if let raw = record.openingHoursRaw?.lowercased(),
               raw.contains("24/7") || raw.contains("00:00-24:00") {
                return 0
            }
            return 1
        case .unknown:
            return 2
        case .lockedCabinet:
            return 3
        case .restricted:
            return 4
        }
    }
}
