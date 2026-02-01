import Foundation

struct StopDTO: Decodable {
    let stopId: String
    let stopName: String
    let stopDesc: String?
    let stopLat: String
    let stopLon: String
    let routes: String?
}

struct NearbyStopsResponse: Decodable {
    let stops: [NearbyStopDTO]
}

struct NearbyStopDTO: Decodable {
    let id: String
    let name: String
    let desc: String?
    let lat: String
    let lon: String
    let routes: String?
    let distance: String
}

struct SearchStopsResponse: Decodable {
    let query: String
    let count: Int
    let stops: [StopDTO]
}
