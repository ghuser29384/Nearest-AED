import Combine
import CoreLocation
import Foundation

@MainActor
final class HeadingManager: NSObject, ObservableObject {
    @Published private(set) var headingDegrees: Double?
    @Published private(set) var isHeadingAvailable: Bool = CLLocationManager.headingAvailable()

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 5
    }

    func start() {
        guard CLLocationManager.headingAvailable() else {
            isHeadingAvailable = false
            return
        }
        manager.startUpdatingHeading()
        isHeadingAvailable = true
    }

    func stop() {
        manager.stopUpdatingHeading()
    }
}

extension HeadingManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            headingDegrees = heading >= 0 ? heading : nil
        }
    }
}
