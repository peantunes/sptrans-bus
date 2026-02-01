import Foundation

class SearchStopsUseCase {
    private let transitRepository: TransitRepositoryProtocol

    init(transitRepository: TransitRepositoryProtocol) {
        self.transitRepository = transitRepository
    }

    func execute(query: String, limit: Int = 10) async throws -> [Stop] {
        return try await transitRepository.searchStops(query: query, limit: limit)
    }
}
