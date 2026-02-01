import Foundation

class GetRouteShapeUseCase {
    private let transitRepository: TransitRepositoryProtocol

    init(transitRepository: TransitRepositoryProtocol) {
        self.transitRepository = transitRepository
    }

    func execute(shapeId: String) async throws -> [Location] {
        return try await transitRepository.getShape(shapeId: shapeId)
    }
}
