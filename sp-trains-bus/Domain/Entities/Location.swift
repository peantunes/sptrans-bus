import Foundation
import CoreLocation

struct Location: Codable {
    let latitude: Double
    let longitude: Double
}

extension Location {
    func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
