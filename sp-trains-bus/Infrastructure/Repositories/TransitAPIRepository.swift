import Foundation

class TransitAPIRepository: TransitRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] {
        let response: NearbyStopsResponse = try await apiClient.request(endpoint: TransitAPIEndpoint.nearby(lat: location.latitude, lon: location.longitude, limit: limit))
        return response.stops.map { $0.toDomain() }
    }

    func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] {
        let response: ArrivalsResponse = try await apiClient.request(endpoint: TransitAPIEndpoint.arrivals(stopId: stopId, limit: limit))
        return response.arrivals.map { $0.toDomain(stopId: stopId) }
    }

    func searchStops(query: String, limit: Int) async throws -> [Stop] {
        let response: SearchStopsResponse = try await apiClient.request(endpoint: TransitAPIEndpoint.search(query: query))
        return response.stops.map { $0.toDomain() }
    }

    func getShape(shapeId: String) async throws -> [Location] {
        let response: ShapeResponse = try await apiClient.request(endpoint: TransitAPIEndpoint.shape(shapeId: shapeId))
        return response.points.map { $0.toDomain() }
    }
    
    func getTrip(tripId: String) async throws -> TripStop {
        let response: TripResponse = try await apiClient.request(endpoint: TransitAPIEndpoint.trip(tripId: tripId))
        return response.trip.toTripStop()
    }
    
    func getRoute(routeId: String) async throws -> Route {
        fatalError("getRoute - Needs to be implemented")
    }

    func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] {
        // The API returns routes directly, no specific limit/offset.
        // We will ignore them for now.
        let response: RoutesResponse = try await apiClient.request(endpoint: TransitAPIEndpoint.routes)
        return response.routes.map { $0.toDomain() }
    }

    func planTrip(origin: Location, destination: Location, maxAlternatives: Int, rankingPriority: String) async throws -> TripPlan {
        let response: PlanResponse = try await apiClient.request(
            endpoint: TransitAPIEndpoint.plan(origin: origin, destination: destination, maxAlternatives: maxAlternatives, rankingPriority: rankingPriority)
        )
        return response.result.toDomain()
    }
}
