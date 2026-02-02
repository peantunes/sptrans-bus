import Foundation

class GetArrivalsUseCase {
    private let transitRepository: TransitRepositoryProtocol

    init(transitRepository: TransitRepositoryProtocol) {
        self.transitRepository = transitRepository
    }

    func execute(stopId: Int, limit: Int = 10) async throws -> [Arrival] {
        return try await transitRepository.getArrivals(stopId: stopId, limit: limit)
    }
}
