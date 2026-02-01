import Foundation

struct RouteDTO: Decodable {
    let routeId: String
    let agencyId: String
    let routeShortName: String
    let routeLongName: String
    let routeType: Int
    let routeColor: String
    let routeTextColor: String
    let trips: [TripDTO]?
}

struct RouteResponse: Decodable {
    let route: RouteDTO
}

struct RoutesResponse: Decodable {
    let routes: [RouteDTO]
}
