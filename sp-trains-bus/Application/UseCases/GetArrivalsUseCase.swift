import Foundation

class GetArrivalsUseCase {
    private let transitRepository: TransitRepositoryProtocol

    init(transitRepository: TransitRepositoryProtocol) {
        self.transitRepository = transitRepository
    }

    func execute(
        stopId: Int,
        limit: Int = 10,
        date: String? = nil,
        time: String? = nil,
        cursorDate: String? = nil,
        cursorTime: String? = nil,
        direction: ArrivalsPageDirection = .next
    ) async throws -> [Arrival] {
        return try await transitRepository.getArrivals(
            stopId: stopId,
            limit: limit,
            date: date,
            time: time,
            cursorDate: cursorDate,
            cursorTime: cursorTime,
            direction: direction
        )
    }
}
