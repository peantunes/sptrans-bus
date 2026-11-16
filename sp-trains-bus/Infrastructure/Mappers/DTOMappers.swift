import Foundation

extension StopDTO {
    func toDomain() -> Stop {
        return Stop(stopId: stopId,
                    stopName: stopName,
                    location: Location(latitude: stopLat, longitude: stopLon),
                    stopSequence: stopSequence ?? 0,
                    routes: routes,
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
                    routes: routes,
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
            waitTime: waitTime,
            serviceDate: serviceDate,
            scheduledTimestamp: scheduledTimestamp
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
                routes: stop.routes,
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
        var plan = TripPlan(alternatives: mappedAlternatives, rankingPriority: rankingPriority ?? "arrives_first")
        if let walk, let origin, let destination {
            let segment = TripPlanWalkSegment(
                fromLabel: NSLocalizedString("Origin", comment: ""),
                toLabel: NSLocalizedString("Destination", comment: ""),
                fromLocation: origin.location, toLocation: destination.location,
                distanceMeters: walk.distanceMeters, durationMinutes: walk.durationMinutes,
                departureTime: departure?.time, arrivalTime: walk.arrivalTime
            )
            var alternative = TripPlanAlternative(type: .walk, departureTime: departure?.time,
                arrivalTime: walk.arrivalTime, legCount: 0, lineSummary: "")
            alternative.durationMinutes = walk.durationMinutes
            alternative.walkMeters = walk.distanceMeters
            alternative.walkMinutes = walk.durationMinutes
            alternative.segments = [.walk(segment)]
            plan.walkingAlternative = alternative
        }
        return plan
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
        var alternative = TripPlanAlternative(
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
        alternative.startTimestamp = summary?.startTimestamp
        alternative.endTimestamp = summary?.endTimestamp
        alternative.startTime = summary?.startTime
        alternative.endTime = summary?.endTime
        alternative.durationMinutes = summary?.durationMinutes
        alternative.transferCount = summary?.transferCount
        alternative.walkMeters = summary?.walkMeters
        alternative.walkMinutes = summary?.walkMinutes
        var legIndex = 0
        alternative.segments = (segments ?? []).compactMap { segment in
            if segment.type == "transit" {
                defer { legIndex += 1 }
                guard mappedLegs.indices.contains(legIndex) else { return nil }
                return .transit(legIndex)
            }
            guard segment.type == "walk", let from = segment.from, let to = segment.to,
                  let distance = segment.distanceMeters, let duration = segment.durationMinutes else { return nil }
            return .walk(TripPlanWalkSegment(
                fromLabel: from.name ?? NSLocalizedString("Origin", comment: ""),
                toLabel: to.name ?? NSLocalizedString("Destination", comment: ""),
                fromLocation: from.location, toLocation: to.location,
                distanceMeters: distance, durationMinutes: duration,
                departureTime: segment.departureTime, arrivalTime: segment.arrivalTime
            ))
        }
        return alternative
    }
}

extension PlanRouteDTO {
    func toDomain() -> TripPlanRoute {
        return TripPlanRoute(
            routeId: routeId ?? "",
            shortName: shortName ?? routeId ?? "",
            longName: longName ?? "",
            color: color ?? "",
            textColor: textColor ?? "",
            type: type
        )
    }
}

extension PlanStopDTO {
    func toDomain(sequence: Int = 0) -> Stop {
        return Stop(
            stopId: id ?? 0,
            stopName: name ?? "Unknown stop",
            location: Location(latitude: lat ?? 0, longitude: lon ?? 0),
            stopSequence: sequence,
            routes: routes,
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
            destinationStop: destinationStop?.toDomain(),
            mode: mode, headsign: headsign,
            departureTime: departureTime, arrivalTime: arrivalTime,
            durationMinutes: durationMinutes, headwayMinutes: headwayMinutes,
            intermediateStops: intermediateStops?.enumerated().map { index, stop in
                stop.toDomain(sequence: index + 1)
            },
            intermediateStopTimes: intermediateStops?.map(\.time) ?? [],
            departureTimestamp: departureTimestamp
        )
    }
}
