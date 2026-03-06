import Foundation

enum AppIntentTransitService {
    static let apiClient = APIClient()

    static func searchStops(query: String, limit: Int = 10) async throws -> [Stop] {
        let response: SearchStopsResponse = try await apiClient.request(endpoint: TransitAPIEndpoint.search(query: query))
        return Array(response.stops.prefix(max(limit, 1))).map { $0.toDomain() }
    }

    static func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] {
        let response: ArrivalsResponse = try await apiClient.request(
            endpoint: TransitAPIEndpoint.arrivals(stopId: stopId, limit: max(limit, 1))
        )
        return response.arrivals.map { $0.toDomain(stopId: stopId) }
    }

    static func getRailStatus() async throws -> RailStatusResponseDTO {
        try await apiClient.request(endpoint: TransitAPIEndpoint.metroCPTM(refresh: false))
    }
}
