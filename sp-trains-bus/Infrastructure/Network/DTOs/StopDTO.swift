import Foundation

struct StopDTO: Decodable {
    let stopId: Int
    let stopName: String
    let stopDesc: String?
    let stopLat: Double
    let stopLon: Double
    let routes: String?
    let stopSequence: Int?
}

struct NearbyStopsResponse: Decodable {
    let stops: [NearbyStopDTO]
}

struct NearbyStopDTO: Decodable {
    let id: Int
    let name: String
    let desc: String?
    let lat: Double
    let lon: Double
    let routes: String?
    let distance: Double
}

struct SearchStopsResponse: Decodable {
    let query: String
    let count: Int
    let stops: [StopDTO]
}
