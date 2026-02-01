import Foundation

class GetNearbyStopsUseCase {
    private let transitRepository: TransitRepositoryProtocol
    private let locationService: LocationServiceProtocol

    init(transitRepository: TransitRepositoryProtocol, locationService: LocationServiceProtocol) {
        self.transitRepository = transitRepository
        self.locationService = locationService
    }

    func execute(limit: Int = 10) async throws -> [Stop] {
        guard let currentLocation = locationService.getCurrentLocation() else {
            // Handle error: location not available
            throw LocationError.locationUnavailable
        }
        return try await transitRepository.getNearbyStops(location: currentLocation, limit: limit)
    }
}

enum LocationError: Error {
    case locationUnavailable
}
