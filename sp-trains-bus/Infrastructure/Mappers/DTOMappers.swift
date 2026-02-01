import Foundation

extension StopDTO {
    func toDomain() -> Stop {
        return Stop(stopId: Int(stopId) ?? 0,
                    stopName: stopName,
                    location: Location(latitude: stopLat, longitude: stopLon),
                    stopSequence: 0, // StopDTO does not have stopSequence
                    stopCode: "", // StopDTO does not have stopCode
                    wheelchairBoarding: 0) // StopDTO does not have wheelchairBoarding
    }
}

extension NearbyStopDTO {
    func toDomain() -> Stop {
        return Stop(stopId: Int(id) ?? 0,
                    stopName: name,
                    location: Location(latitude: lat, longitude: lon),
                    stopSequence: 0,
                    stopCode: "",
                    wheelchairBoarding: 0)
    }
}

extension ArrivalDTO {
    func toDomain() -> Arrival {
        return Arrival(tripId: tripId,
                       arrivalTime: arrivalTime,
                       departureTime: departureTime,
                       stopId: Int(stopId) ?? 0,
                       stopSequence: stopSequence,
                       stopHeadsign: headsign,
                       pickupType: 0, // ArrivalDTO does not have pickupType
                       dropOffType: 0, // ArrivalDTO does not have dropOffType
                       shapeDistTraveled: "", // ArrivalDTO does not have shapeDistTraveled
                       frequency: frequency,
                       waitTime: waitTime)
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
