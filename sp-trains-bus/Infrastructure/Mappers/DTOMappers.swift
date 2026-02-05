import Foundation

extension StopDTO {
    func toDomain() -> Stop {
        return Stop(stopId: stopId,
                    stopName: stopName,
                    location: Location(latitude: stopLat, longitude: stopLon),
                    stopSequence: stopSequence ?? 0,
                    stopCode: "", // StopDTO does not have stopCode
                    wheelchairBoarding: 0) // StopDTO does not have wheelchairBoarding
    }
}

extension NearbyStopDTO {
    func toDomain() -> Stop {
        return Stop(stopId: id,
                    stopName: name,
                    location: Location(latitude: Double(lat) ?? 0, longitude: Double(lon) ?? 0),
                    stopSequence: 0,
                    stopCode: "",
                    wheelchairBoarding: 0)
    }
}

extension ArrivalDTO {
    func toDomain(stopId: Int) -> Arrival {
        return Arrival(
            tripId: tripId,
            routeId: routeId,
            routeShortName: routeShortName,
            routeLongName: routeLongName,
            headsign: headsign,
            arrivalTime: arrivalTime,
            departureTime: departureTime,
            stopId: stopId,
            stopSequence: stopSequence,
            routeType: routeType,
            routeColor: routeColor,
            routeTextColor: routeTextColor,
            frequency: frequency,
            waitTime: waitTime
        )
    }
}

extension TripDTO {
    func toDomain() -> Trip {
        return Trip(routeId: routeId,
                    serviceId: serviceId,
                    tripId: tripId,
                    tripHeadsign: headsign,
                    directionId: directionId,
                    shapeId: shapeId)
    }

    func toTripStop() -> TripStop {
        let trip = toDomain()
        let mappedStops = stops.enumerated().map { index, stop in
            Stop(
                stopId: stop.stopId,
                stopName: stop.stopName,
                location: Location(latitude: stop.stopLat, longitude: stop.stopLon),
                stopSequence: stop.stopSequence ?? index + 1,
                stopCode: "",
                wheelchairBoarding: 0
            )
        }
        return TripStop(trip: trip, stops: mappedStops)
    }
}

extension RouteDTO {
    func toDomain() -> Route {
        return Route(routeId: routeId,
                     agencyId: Int(agencyId) ?? 0,
                     routeShortName: routeShortName,
                     routeLongName: routeLongName,
                     routeDesc: "", // RouteDTO does not have routeDesc
                     routeType: routeType,
                     routeColor: routeColor,
                     routeTextColor: routeTextColor)
    }
}

extension PlanResultDTO {
    func toDomain() -> TripPlan {
        let mappedAlternatives = alternatives.map { $0.toDomain() }
        return TripPlan(alternatives: mappedAlternatives, rankingPriority: rankingPriority ?? "arrives_first")
    }
}

extension PlanAlternativeDTO {
    func toDomain() -> TripPlanAlternative {
        let typeValue = TripPlanAlternativeType(rawValue: type) ?? .unknown
        let dataRoute = data?.route?.toDomain()
        let originRoute = data?.originRoute?.toDomain()
        let destinationRoute = data?.destinationRoute?.toDomain()
        let originStop = data?.originStop?.toDomain()
        let destinationStop = data?.destinationStop?.toDomain()
        let transferStop = data?.transferStop?.toDomain()

        let mappedLegs = legs?.map { $0.toDomain() } ?? []
        return TripPlanAlternative(
            type: typeValue,
            departureTime: summary?.departureTime,
            arrivalTime: summary?.arrivalTime,
            legCount: summary?.legCount ?? (typeValue == .transfer ? 2 : 1),
            stopCount: summary?.stopCount,
            lineSummary: summary?.lineSummary ?? "",
            legs: mappedLegs,
            tripId: data?.tripId,
            originTripId: data?.originTripId,
            destinationTripId: data?.destinationTripId,
            originStopId: data?.originStopId,
            destinationStopId: data?.destinationStopId,
            transferStopId: data?.transferStopId,
            route: dataRoute,
            originRoute: originRoute,
            destinationRoute: destinationRoute,
            originStop: originStop,
            destinationStop: destinationStop,
            transferStop: transferStop
        )
    }
}

extension PlanRouteDTO {
    func toDomain() -> TripPlanRoute {
        return TripPlanRoute(
            routeId: routeId ?? "",
            shortName: shortName ?? routeId ?? "",
            longName: longName ?? "",
            color: color ?? "",
            textColor: textColor ?? ""
        )
    }
}

extension PlanStopDTO {
    func toDomain() -> Stop {
        return Stop(
            stopId: id ?? 0,
            stopName: name ?? "Unknown stop",
            location: Location(latitude: lat ?? 0, longitude: lon ?? 0),
            stopSequence: 0,
            stopCode: "",
            wheelchairBoarding: 0
        )
    }
}

extension PlanLegDTO {
    func toDomain() -> TripPlanLeg {
        return TripPlanLeg(
            route: route?.toDomain(),
            tripId: tripId,
            originStopId: originStopId,
            destinationStopId: destinationStopId,
            originStop: originStop?.toDomain(),
            destinationStop: destinationStop?.toDomain()
        )
    }
}
