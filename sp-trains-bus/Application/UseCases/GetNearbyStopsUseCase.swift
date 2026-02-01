import Foundation
import CoreLocation

class GetNearbyStopsUseCase {
    private let transitRepository: TransitRepositoryProtocol
    private let locationService: LocationServiceProtocol

    init(transitRepository: TransitRepositoryProtocol, locationService: LocationServiceProtocol) {
        self.transitRepository = transitRepository
        self.locationService = locationService
    }

    func execute(limit: Int = 10, location: Location?) async throws -> [Stop] {
        let currentLocation = location ?? locationService.getCurrentLocation()
        guard let currentLocation else {
            // Handle error: location not available
            throw LocationError.locationUnavailable
        }
        return try await transitRepository.getNearbyStops(location: currentLocation, limit: limit)
    }
}

enum LocationError: Error {
    case locationUnavailable
}
