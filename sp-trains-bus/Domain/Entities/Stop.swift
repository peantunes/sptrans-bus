import Foundation

struct Stop: Codable, Identifiable {
    enum TransportType {
        case bus
        case metro
        case train
    }
    var id: Int {
        stopId
    }
    let stopId: Int
    let stopName: String
    let location: Location
    let stopSequence: Int
    let routes: String?
    let stopCode: String
    let wheelchairBoarding: Int
    
    var transportType: TransportType {
        if routes?.contains("METRÔ") == true {
            return .metro
        } else if routes?.contains("CPTM") == true {
            return .train
        }
        return .bus
    }
}
