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
    let serviceDate: String?
    let scheduledTimestamp: Int?
}

struct ArrivalsResponse: Decodable {
    let stopId: String?
    let queryTime: String?
    let queryDate: String?
    let queryTimezone: String?
    let count: Int?
    let arrivals: [ArrivalDTO]
}
