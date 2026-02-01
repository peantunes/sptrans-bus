import Foundation

class GetTripRouteUseCase {
    private let transitRepository: TransitRepositoryProtocol

    init(transitRepository: TransitRepositoryProtocol) {
        self.transitRepository = transitRepository
    }

    func execute(tripId: String) async throws -> Trip {
        return try await transitRepository.getTrip(tripId: tripId)
    }
}
