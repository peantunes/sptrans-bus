import Foundation

struct TripDTO: Decodable {
    let tripId: String
    let routeId: String
    let serviceId: String
    let headsign: String
    let directionId: Int
    let shapeId: String
    let stops: [StopDTO]
}

struct TripResponse: Decodable {
    let trip: TripDTO
}
