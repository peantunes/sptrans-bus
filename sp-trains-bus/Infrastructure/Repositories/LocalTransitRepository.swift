import Foundation
import SwiftData
import CoreLocation

enum LocalTransitRepositoryError: LocalizedError {
    case noImportedData
    case routeNotFound
    case tripNotFound
    case unsupportedLocalOperation

    var errorDescription: String? {
        switch self {
        case .noImportedData:
            return "Local GTFS data is not available yet."
        case .routeNotFound:
            return "Route was not found in local GTFS data."
        case .tripNotFound:
            return "Trip was not found in local GTFS data."
        case .unsupportedLocalOperation:
            return "This operation is not supported by local GTFS mode."
        }
    }
}

final class LocalTransitRepository: TransitRepositoryProtocol {
    private let modelContainer: ModelContainer
    private let calendar: Calendar

    init(modelContainer: ModelContainer, calendar: Calendar = .current) {
        self.modelContainer = modelContainer
        self.calendar = calendar
    }

    func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] {
        let context = ModelContext(modelContainer)
        try ensureGTFSData(in: context)

        let stops = try context.fetch(FetchDescriptor<GTFSStopModel>())
        let userPoint = CLLocation(latitude: location.latitude, longitude: location.longitude)

        return stops
            .map { stop -> (Stop, CLLocationDistance) in
                let stopPoint = CLLocation(latitude: stop.stopLat, longitude: stop.stopLon)
                let distance = userPoint.distance(from: stopPoint)
                return (toStop(stop), distance)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] {
        let context = ModelContext(modelContainer)
        try ensureGTFSData(in: context)

        let targetStopId = stopId
        let stopTimesDescriptor = FetchDescriptor<GTFSStopTimeModel>(
            predicate: #Predicate { model in
                model.stopId == targetStopId
            }
        )
        let stopTimesAtStop = try context.fetch(stopTimesDescriptor)
        if stopTimesAtStop.isEmpty {
            return []
        }

        let trips = try context.fetch(FetchDescriptor<GTFSTripModel>())
        let routes = try context.fetch(FetchDescriptor<GTFSRouteModel>())
        let calendars = try context.fetch(FetchDescriptor<GTFSCalendarModel>())

        let tripsById = Dictionary(uniqueKeysWithValues: trips.map { ($0.tripId, $0) })
        let routesById = Dictionary(uniqueKeysWithValues: routes.map { ($0.routeId, $0) })
        let calendarsByServiceId = Dictionary(uniqueKeysWithValues: calendars.map { ($0.serviceId, $0) })

        let now = Date()
        let currentMinutes = minutesSinceStartOfDay(from: now)
        let currentDateString = dateYYYYMMDD(from: now)
        let weekday = calendar.component(.weekday, from: now)

        let arrivals = stopTimesAtStop.compactMap { stopTime -> Arrival? in
            guard let trip = tripsById[stopTime.tripId] else { return nil }
            guard isServiceActive(
                serviceId: trip.serviceId,
                dateString: currentDateString,
                weekday: weekday,
                calendarsByServiceId: calendarsByServiceId
            ) else {
                return nil
            }
            guard let route = routesById[trip.routeId] else { return nil }
            guard let arrivalMinutes = minutes(fromTimeString: stopTime.arrivalTime) else { return nil }
            let waitTime = arrivalMinutes - currentMinutes
            guard waitTime >= 0 else { return nil }

            return Arrival(
                tripId: trip.tripId,
                routeId: route.routeId,
                routeShortName: route.routeShortName,
                routeLongName: route.routeLongName,
                headsign: trip.tripHeadsign,
                arrivalTime: stopTime.arrivalTime,
                departureTime: stopTime.departureTime,
                stopId: stopTime.stopId,
                stopSequence: stopTime.stopSequence,
                routeType: route.routeType,
                routeColor: route.routeColor,
                routeTextColor: route.routeTextColor,
                frequency: nil,
                waitTime: waitTime
            )
        }

        return arrivals
            .sorted { $0.waitTime < $1.waitTime }
            .prefix(limit)
            .map { $0 }
    }

    func searchStops(query: String, limit: Int) async throws -> [Stop] {
        let context = ModelContext(modelContainer)
        try ensureGTFSData(in: context)

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return [] }

        let stops = try context.fetch(FetchDescriptor<GTFSStopModel>())
        return stops
            .filter { stop in
                stop.stopName.lowercased().contains(normalizedQuery) ||
                stop.stopCode.lowercased().contains(normalizedQuery)
            }
            .prefix(limit)
            .map { toStop($0) }
    }

    func getTrip(tripId: String) async throws -> TripStop {
        let context = ModelContext(modelContainer)
        try ensureGTFSData(in: context)

        let trips = try context.fetch(FetchDescriptor<GTFSTripModel>())
        guard let tripModel = trips.first(where: { $0.tripId == tripId }) else {
            throw LocalTransitRepositoryError.tripNotFound
        }

        let stopTimes = try context.fetch(FetchDescriptor<GTFSStopTimeModel>())
            .filter { $0.tripId == tripId }
            .sorted { $0.stopSequence < $1.stopSequence }

        let stops = try context.fetch(FetchDescriptor<GTFSStopModel>())
        let stopById = Dictionary(uniqueKeysWithValues: stops.map { ($0.stopId, $0) })

        let orderedStops: [Stop] = stopTimes.compactMap { stopTime in
            guard let stop = stopById[stopTime.stopId] else { return nil }
            return Stop(
                stopId: stop.stopId,
                stopName: stop.stopName,
                location: Location(latitude: stop.stopLat, longitude: stop.stopLon),
                stopSequence: stopTime.stopSequence,
                stopCode: stop.stopCode,
                wheelchairBoarding: stop.wheelchairBoarding
            )
        }

        return TripStop(trip: toTrip(tripModel), stops: orderedStops)
    }

    func getRoute(routeId: String) async throws -> Route {
        let context = ModelContext(modelContainer)
        try ensureGTFSData(in: context)

        let routes = try context.fetch(FetchDescriptor<GTFSRouteModel>())
        guard let routeModel = routes.first(where: { $0.routeId == routeId }) else {
            throw LocalTransitRepositoryError.routeNotFound
        }

        return toRoute(routeModel)
    }

    func getShape(shapeId: String) async throws -> [Location] {
        let context = ModelContext(modelContainer)
        try ensureGTFSData(in: context)

        let points = try context.fetch(FetchDescriptor<GTFSShapePointModel>())
            .filter { $0.shapeId == shapeId }
            .sorted { $0.shapePtSequence < $1.shapePtSequence }

        return points.map { Location(latitude: $0.shapePtLat, longitude: $0.shapePtLon) }
    }

    func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] {
        let context = ModelContext(modelContainer)
        try ensureGTFSData(in: context)

        let routes = try context.fetch(FetchDescriptor<GTFSRouteModel>())
            .sorted { $0.routeShortName < $1.routeShortName }

        guard offset < routes.count else { return [] }
        let upperBound = min(routes.count, offset + limit)
        return routes[offset..<upperBound].map { toRoute($0) }
    }

    func planTrip(origin: Location, destination: Location, maxAlternatives: Int, rankingPriority: String) async throws -> TripPlan {
        throw LocalTransitRepositoryError.unsupportedLocalOperation
    }

    private func ensureGTFSData(in context: ModelContext) throws {
        var descriptor = FetchDescriptor<GTFSStopModel>()
        descriptor.fetchLimit = 1
        if try context.fetch(descriptor).isEmpty {
            throw LocalTransitRepositoryError.noImportedData
        }
    }

    private func toStop(_ model: GTFSStopModel) -> Stop {
        Stop(
            stopId: model.stopId,
            stopName: model.stopName,
            location: Location(latitude: model.stopLat, longitude: model.stopLon),
            stopSequence: 0,
            stopCode: model.stopCode,
            wheelchairBoarding: model.wheelchairBoarding
        )
    }

    private func toRoute(_ model: GTFSRouteModel) -> Route {
        Route(
            routeId: model.routeId,
            agencyId: model.agencyId,
            routeShortName: model.routeShortName,
            routeLongName: model.routeLongName,
            routeDesc: model.routeDesc,
            routeType: model.routeType,
            routeColor: model.routeColor,
            routeTextColor: model.routeTextColor
        )
    }

    private func toTrip(_ model: GTFSTripModel) -> Trip {
        Trip(
            routeId: model.routeId,
            serviceId: model.serviceId,
            tripId: model.tripId,
            tripHeadsign: model.tripHeadsign,
            directionId: model.directionId,
            shapeId: model.shapeId
        )
    }

    private func minutesSinceStartOfDay(from date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return (hour * 60) + minute
    }

    private func minutes(fromTimeString value: String) -> Int? {
        let components = value.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        return (hour * 60) + minute
    }

    private func dateYYYYMMDD(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private func isServiceActive(
        serviceId: String,
        dateString: String,
        weekday: Int,
        calendarsByServiceId: [String: GTFSCalendarModel]
    ) -> Bool {
        // Some feeds use only calendar_dates; if calendar is missing we keep the service active.
        guard !calendarsByServiceId.isEmpty else { return true }
        guard let calendarModel = calendarsByServiceId[serviceId] else { return false }
        guard dateString >= calendarModel.startDate && dateString <= calendarModel.endDate else { return false }

        switch weekday {
        case 1: return calendarModel.sunday
        case 2: return calendarModel.monday
        case 3: return calendarModel.tuesday
        case 4: return calendarModel.wednesday
        case 5: return calendarModel.thursday
        case 6: return calendarModel.friday
        case 7: return calendarModel.saturday
        default: return false
        }
    }
}
