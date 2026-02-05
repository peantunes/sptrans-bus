import Foundation

class PlanTripUseCase {
    private let transitRepository: TransitRepositoryProtocol

    init(transitRepository: TransitRepositoryProtocol) {
        self.transitRepository = transitRepository
    }

    func execute(origin: Location, destination: Location, maxAlternatives: Int = 5, rankingPriority: String = "arrives_first") async throws -> TripPlan {
        return try await transitRepository.planTrip(
            origin: origin,
            destination: destination,
            maxAlternatives: maxAlternatives,
            rankingPriority: rankingPriority
        )
    }
}
