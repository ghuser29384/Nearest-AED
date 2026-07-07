import Foundation

struct LocationSnapshot: Equatable, Codable {
    var coordinate: Coordinate
    var timestamp: Date
    var horizontalAccuracy: Double
    var isMarkedStale: Bool = false

    static let defaultFreshAge: TimeInterval = 120

    init(coordinate: Coordinate, timestamp: Date, horizontalAccuracy: Double, isMarkedStale: Bool = false) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.isMarkedStale = isMarkedStale
    }

    func isStale(relativeTo now: Date = Date(), maximumAge: TimeInterval = defaultFreshAge) -> Bool {
        isMarkedStale || now.timeIntervalSince(timestamp) > maximumAge
    }

    func markedStale() -> LocationSnapshot {
        LocationSnapshot(
            coordinate: coordinate,
            timestamp: timestamp,
            horizontalAccuracy: horizontalAccuracy,
            isMarkedStale: true
        )
    }
}

enum LocationAvailability: Equatable {
    case fresh(LocationSnapshot)
    case stale(LocationSnapshot)
    case unavailable
}

enum LocationFreshnessEvaluator {
    static func bestAvailable(
        current: LocationSnapshot?,
        lastKnown: LocationSnapshot?,
        now: Date = Date(),
        maximumFreshAge: TimeInterval = LocationSnapshot.defaultFreshAge
    ) -> LocationAvailability {
        if let current {
            return current.isStale(relativeTo: now, maximumAge: maximumFreshAge) ? .stale(current.markedStale()) : .fresh(current)
        }

        if let lastKnown {
            return .stale(lastKnown.markedStale())
        }

        return .unavailable
    }
}

