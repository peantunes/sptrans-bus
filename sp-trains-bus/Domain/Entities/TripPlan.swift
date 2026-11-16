import Foundation

struct TripPlan {
    let alternatives: [TripPlanAlternative]
    let rankingPriority: String
    var walkingAlternative: TripPlanAlternative? = nil
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
    var startTime: String?
    var endTime: String?
    var startTimestamp: TimeInterval?
    var endTimestamp: TimeInterval?
    var durationMinutes: Int?
    var transferCount: Int?
    var walkMeters: Double?
    var walkMinutes: Int?
    var segments: [TripPlanSegment] = []

    var displayDepartureTime: String { TripPlanTime.display(startTime ?? departureTime) }
    var displayArrivalTime: String { TripPlanTime.display(endTime ?? arrivalTime) }
    var transfers: Int { transferCount ?? max(0, legCount - 1) }
    var transferDescription: String {
        if type == .walk { return NSLocalizedString("Walking", comment: "") }
        if transfers == 0 { return NSLocalizedString("No transfers", comment: "") }
        if transfers == 1 { return NSLocalizedString("1 transfer", comment: "") }
        return String(format: NSLocalizedString("%d transfers", comment: ""), transfers)
    }
    
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

extension TripPlanAlternative {
    var vehicleLegs: [TripPlanLeg] {
        let alternative = self
        if alternative.type == .walk { return [] }
        if !alternative.legs.isEmpty {
            return alternative.legs
        }

        if alternative.type == .transfer {
            let first = TripPlanLeg(
                route: alternative.originRoute,
                tripId: alternative.originTripId,
                originStopId: alternative.originStopId,
                destinationStopId: alternative.transferStopId,
                originStop: alternative.originStop,
                destinationStop: alternative.transferStop
            )
            let second = TripPlanLeg(
                route: alternative.destinationRoute,
                tripId: alternative.destinationTripId,
                originStopId: alternative.transferStopId,
                destinationStopId: alternative.destinationStopId,
                originStop: alternative.transferStop,
                destinationStop: alternative.destinationStop
            )
            return [first, second]
        }

        return [TripPlanLeg(
            route: alternative.route,
            tripId: alternative.tripId,
            originStopId: alternative.originStopId,
            destinationStopId: alternative.destinationStopId,
            originStop: alternative.originStop,
            destinationStop: alternative.destinationStop
        )]
    }

}

enum TripPlanAlternativeType: String {
    case walk
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
    var type: Int? = nil
}

struct TripPlanLeg: Identifiable {
    let id = UUID()
    let route: TripPlanRoute?
    let tripId: String?
    let originStopId: Int?
    let destinationStopId: Int?
    let originStop: Stop?
    let destinationStop: Stop?
    var mode: String? = nil
    var headsign: String? = nil
    var departureTime: String? = nil
    var arrivalTime: String? = nil
    var durationMinutes: Int? = nil
    var headwayMinutes: Int? = nil
    var intermediateStops: [Stop]? = nil
    var intermediateStopTimes: [String?] = []
    var departureTimestamp: TimeInterval? = nil

    var systemImage: String {
        switch mode {
        case "metro": return "tram.fill"
        case "rail": return "train.side.front.car"
        default: return "bus.fill"
        }
    }
}

struct TripPlanningOptions: Sendable {
    let departure: Date?
    let maxTransfers: Int

    nonisolated init(departure: Date? = nil, maxTransfers: Int = 3) {
        self.departure = departure
        self.maxTransfers = min(4, max(0, maxTransfers))
    }
}

enum TripPlanSegment {
    case walk(TripPlanWalkSegment)
    case transit(Int) // Index in the alternative's vehicle legs.
}

enum TripPlanTime {
    static func duration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let remainder = minutes % 60
        return remainder == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(remainder) min"
    }

    static func display(_ value: String?) -> String {
        guard let value else { return "--:--" }
        let parts = value.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return value }
        let clock = String(format: "%02d:%02d", hour % 24, minute)
        return hour >= 24 ? "\(clock) (+\(hour / 24)d)" : clock
    }
}


struct TripPlanWalkSegment: Identifiable {
    let id = UUID()
    let fromLabel: String
    let toLabel: String
    let fromLocation: Location
    let toLocation: Location
    let distanceMeters: Double
    let durationMinutes: Int

    var departureTime: String? = nil
    var arrivalTime: String? = nil

    var distanceText: String {
        if distanceMeters >= 1000 {
            return String(format: "%.1f km", distanceMeters / 1000)
        }
        return "\(Int(distanceMeters)) m"
    }

    var durationText: String {
        durationMinutes == 1 ? "1 min" : "\(durationMinutes) min"
    }
}
