import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentLocation: LocationSnapshot?
    @Published private(set) var lastKnownLocation: LocationSnapshot?
    @Published private(set) var statusMessage: String = "Location not requested."

    private let manager = CLLocationManager()
    private let storageKey = "AEDNowOffline.lastKnownLocation"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        authorizationStatus = manager.authorizationStatus
        lastKnownLocation = loadPersistedLocation()
    }

    func requestWhenInUsePermission() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestOneShotLocation() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            statusMessage = "Getting current location."
            manager.requestLocation()
        case .denied, .restricted:
            statusMessage = "Location unavailable. Use the AED list fallback."
        @unknown default:
            statusMessage = "Location unavailable. Use the AED list fallback."
        }
    }

    func bestAvailableLocation(now: Date = Date()) -> LocationAvailability {
        LocationFreshnessEvaluator.bestAvailable(
            current: currentLocation,
            lastKnown: lastKnownLocation,
            now: now
        )
    }

    func applyTestingLocation(_ snapshot: LocationSnapshot) {
        currentLocation = snapshot.isMarkedStale ? nil : snapshot
        lastKnownLocation = snapshot
        statusMessage = snapshot.isMarkedStale ? "Location may be outdated." : "Current location ready."
    }

    private func updateLocation(_ location: CLLocation) {
        guard CLLocationCoordinate2DIsValid(location.coordinate),
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 500
        else {
            statusMessage = "Location accuracy is too low. Use the AED list fallback."
            return
        }

        let snapshot = LocationSnapshot(
            coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy
        )
        currentLocation = snapshot
        lastKnownLocation = snapshot
        persist(snapshot)
        statusMessage = snapshot.isStale() ? "Location may be outdated." : "Current location ready."
    }

    private func persist(_ snapshot: LocationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadPersistedLocation() -> LocationSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(LocationSnapshot.self, from: data)
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                requestOneShotLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.sorted(by: { $0.timestamp > $1.timestamp }).first else { return }
        Task { @MainActor in
            updateLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            statusMessage = "Location unavailable. Use the AED list fallback."
        }
    }
}
