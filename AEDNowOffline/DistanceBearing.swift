import Foundation

struct Coordinate: Equatable, Codable {
    var latitude: Double
    var longitude: Double
}

enum DistanceBearing {
    static let earthRadiusMeters = 6_371_000.0

    static func distanceMeters(from start: Coordinate, to end: Coordinate) -> Double {
        let lat1 = radians(start.latitude)
        let lat2 = radians(end.latitude)
        let deltaLat = radians(end.latitude - start.latitude)
        let deltaLon = radians(end.longitude - start.longitude)

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }

    static func bearingDegrees(from start: Coordinate, to end: Coordinate) -> Double {
        let lat1 = radians(start.latitude)
        let lat2 = radians(end.latitude)
        let deltaLon = radians(end.longitude - start.longitude)

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        return normalizedDegrees(degrees(atan2(y, x)))
    }

    static func relativeBearingDegrees(bearing: Double, heading: Double?) -> Double {
        guard let heading else { return bearing }
        return normalizedDegrees(bearing - heading)
    }

    static func compassDirection(for bearing: Double) -> String {
        let directions = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
        let index = Int((normalizedDegrees(bearing) + 22.5) / 45.0) % directions.count
        return directions[index]
    }

    static func formattedDistance(_ meters: Double) -> String {
        if meters < 1_000 {
            return "\(Int(meters.rounded())) m"
        }
        return String(format: "%.1f km", meters / 1_000)
    }

    private static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func degrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }

    private static func normalizedDegrees(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }
}

