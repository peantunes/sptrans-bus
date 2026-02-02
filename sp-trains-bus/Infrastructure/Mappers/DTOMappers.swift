import Foundation

extension StopDTO {
    func toDomain() -> Stop {
        return Stop(stopId: stopId,
                    stopName: stopName,
                    location: Location(latitude: stopLat, longitude: stopLon),
                    stopSequence: 0, // StopDTO does not have stopSequence
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
