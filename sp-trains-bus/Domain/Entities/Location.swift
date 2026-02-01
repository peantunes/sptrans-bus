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
    
    static let saoPaulo = Location(latitude: -23.5505, longitude: -46.6333)
}
