import Foundation

struct PlanResponse: Decodable {
    let result: PlanResultDTO
}

struct PlanResultDTO: Decodable {
    let alternatives: [PlanAlternativeDTO]
    let rankingPriority: String?
}

struct PlanAlternativeDTO: Decodable {
    let type: String
    let summary: PlanAlternativeSummaryDTO?
    let legs: [PlanLegDTO]?
    let data: PlanAlternativeDataDTO?
}

struct PlanAlternativeSummaryDTO: Decodable {
    let departureTime: String?
    let arrivalTime: String?
    let legCount: Int?
    let stopCount: Int?
    let lineSummary: String?
}

struct PlanAlternativeDataDTO: Decodable {
    let route: PlanRouteDTO?
    let originRoute: PlanRouteDTO?
    let destinationRoute: PlanRouteDTO?
    let tripId: String?
    let originTripId: String?
    let destinationTripId: String?
    let originStopId: Int?
    let destinationStopId: Int?
    let transferStopId: Int?
    let originStop: PlanStopDTO?
    let destinationStop: PlanStopDTO?
    let transferStop: PlanStopDTO?
}

struct PlanLegDTO: Decodable {
    let route: PlanRouteDTO?
    let tripId: String?
    let originStopId: Int?
    let destinationStopId: Int?
    let originStop: PlanStopDTO?
    let destinationStop: PlanStopDTO?
}

struct PlanRouteDTO: Decodable {
    let routeId: String?
    let shortName: String?
    let longName: String?
    let color: String?
    let textColor: String?
}

struct PlanStopDTO: Decodable {
    let id: Int?
    let name: String?
    let desc: String?
    let lat: Double?
    let lon: Double?
    let routes: String?
    let distance: Double?
}
