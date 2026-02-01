import Foundation

struct Arrival: Identifiable {
    let id = UUID() // Add identifiable conformance for use in ForEach
    let tripId: String
    let arrivalTime: String
    let departureTime: String
    let stopId: String
    let stopSequence: Int
    let stopHeadsign: String
    let pickupType: Int
    let dropOffType: Int
    let shapeDistTraveled: String
    let frequency: Int?
    let waitTime: Int
}
