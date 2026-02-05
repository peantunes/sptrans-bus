import Foundation

struct TripPlan {
    let alternatives: [TripPlanAlternative]
    let rankingPriority: String
}

struct TripPlanAlternative: Identifiable {
    let id = UUID()
    let type: TripPlanAlternativeType
    let departureTime: String?
    let arrivalTime: String?
    let legCount: Int
    let stopCount: Int?
    let lineSummary: String
    let legs: [TripPlanLeg]
    let tripId: String?
    let originTripId: String?
    let destinationTripId: String?
    let originStopId: Int?
    let destinationStopId: Int?
    let transferStopId: Int?
    let route: TripPlanRoute?
    let originRoute: TripPlanRoute?
    let destinationRoute: TripPlanRoute?
    let originStop: Stop?
    let destinationStop: Stop?
    let transferStop: Stop?
    
    init(type: TripPlanAlternativeType, departureTime: String? = nil, arrivalTime: String? = nil, legCount: Int, stopCount: Int? = nil, lineSummary: String, legs: [TripPlanLeg] = [], tripId: String? = nil, originTripId: String? = nil, destinationTripId: String? = nil, originStopId: Int? = nil, destinationStopId: Int? = nil, transferStopId: Int? = nil, route: TripPlanRoute? = nil, originRoute: TripPlanRoute? = nil, destinationRoute: TripPlanRoute? = nil, originStop: Stop? = nil, destinationStop: Stop? = nil, transferStop: Stop? = nil) {
        self.type = type
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.legCount = legCount
        self.stopCount = stopCount
        self.lineSummary = lineSummary
        self.legs = legs
        self.tripId = tripId
        self.originTripId = originTripId
        self.destinationTripId = destinationTripId
        self.originStopId = originStopId
        self.destinationStopId = destinationStopId
        self.transferStopId = transferStopId
        self.route = route
        self.originRoute = originRoute
        self.destinationRoute = destinationRoute
        self.originStop = originStop
        self.destinationStop = destinationStop
        self.transferStop = transferStop
    }
}

enum TripPlanAlternativeType: String {
    case direct
    case transfer
    case unknown
}

struct TripPlanRoute {
    let routeId: String
    let shortName: String
    let longName: String
    let color: String
    let textColor: String
}

struct TripPlanLeg: Identifiable {
    let id = UUID()
    let route: TripPlanRoute?
    let tripId: String?
    let originStopId: Int?
    let destinationStopId: Int?
    let originStop: Stop?
    let destinationStop: Stop?
}
