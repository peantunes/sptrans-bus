import Foundation
import CoreLocation

struct Location: Codable {
    let latitude: Double
    let longitude: Double
}

extension Location: Equatable {
    func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: Location) -> CLLocationDistance {
        let origin = CLLocation(latitude: latitude, longitude: longitude)
        let destination = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return origin.distance(from: destination)
    }
    
    static let saoPaulo = Location(latitude: -23.5505, longitude: -46.6333)
}
