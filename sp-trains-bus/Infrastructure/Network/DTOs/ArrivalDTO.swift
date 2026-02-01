import Foundation

struct ArrivalDTO: Decodable {
    let tripId: String
    let routeId: String
    let routeShortName: String
    let routeLongName: String
    let headsign: String
    let arrivalTime: String
    let departureTime: String
    let stopSequence: Int
    let routeType: Int
    let routeColor: String
    let routeTextColor: String
    let frequency: Int?
    let waitTime: Int
}

struct ArrivalsResponse: Decodable {
    let arrivals: [ArrivalDTO]
}
