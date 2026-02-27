import Foundation

protocol TransitRepositoryProtocol {
    func getNearbyStops(location: Location, limit: Int) async throws -> [Stop]
    func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival]
    func getArrivals(
        stopId: Int,
        limit: Int,
        date: String?,
        time: String?,
        cursorDate: String?,
        cursorTime: String?,
        direction: ArrivalsPageDirection
    ) async throws -> [Arrival]
    func searchStops(query: String, limit: Int) async throws -> [Stop]
    func getTrip(tripId: String) async throws -> TripStop
    func getRoute(routeId: String) async throws -> Route
    func getShape(shapeId: String) async throws -> [Location]
    func getAllRoutes(limit: Int, offset: Int) async throws -> [Route]
    func planTrip(origin: Location, destination: Location, maxAlternatives: Int, rankingPriority: String) async throws -> TripPlan
}

extension TransitRepositoryProtocol {
    func getArrivals(
        stopId: Int,
        limit: Int,
        date: String?,
        time: String?,
        cursorDate: String?,
        cursorTime: String?,
        direction: ArrivalsPageDirection
    ) async throws -> [Arrival] {
        // Default compatibility path for repositories that only support basic arrivals.
        return try await getArrivals(stopId: stopId, limit: limit)
    }
}
