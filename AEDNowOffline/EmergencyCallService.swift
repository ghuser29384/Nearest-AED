import Foundation
import UIKit

@MainActor
struct EmergencyCallService {
    var settings: EmergencyRegionSettings = .unitedKingdom

    func openCallPrompt() {
        guard let url = URL(string: "tel://\(settings.dialNumber)") else { return }
        UIApplication.shared.open(url)
    }
}

