import Foundation

final class ConfigurableTransitRepository: TransitRepositoryProtocol {
    private let remoteRepository: TransitRepositoryProtocol
    private let localRepository: TransitRepositoryProtocol
    private let modeService: TransitDataModeServiceProtocol
    private let feedService: GTFSFeedServiceProtocol

    init(
        remoteRepository: TransitRepositoryProtocol,
        localRepository: TransitRepositoryProtocol,
        modeService: TransitDataModeServiceProtocol,
        feedService: GTFSFeedServiceProtocol
    ) {
        self.remoteRepository = remoteRepository
        self.localRepository = localRepository
        self.modeService = modeService
        self.feedService = feedService
    }

    func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] {
        try await execute(local: {
            try await localRepository.getNearbyStops(location: location, limit: limit)
        }, remote: {
            try await remoteRepository.getNearbyStops(location: location, limit: limit)
        })
    }

    func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] {
        try await execute(local: {
            try await localRepository.getArrivals(stopId: stopId, limit: limit)
        }, remote: {
            try await remoteRepository.getArrivals(stopId: stopId, limit: limit)
        })
    }

    func searchStops(query: String, limit: Int) async throws -> [Stop] {
        try await execute(local: {
            try await localRepository.searchStops(query: query, limit: limit)
        }, remote: {
            try await remoteRepository.searchStops(query: query, limit: limit)
        })
    }

    func getTrip(tripId: String) async throws -> TripStop {
        try await execute(local: {
            try await localRepository.getTrip(tripId: tripId)
        }, remote: {
            try await remoteRepository.getTrip(tripId: tripId)
        })
    }

    func getRoute(routeId: String) async throws -> Route {
        try await execute(local: {
            try await localRepository.getRoute(routeId: routeId)
        }, remote: {
            try await remoteRepository.getRoute(routeId: routeId)
        })
    }

    func getShape(shapeId: String) async throws -> [Location] {
        try await execute(local: {
            try await localRepository.getShape(shapeId: shapeId)
        }, remote: {
            try await remoteRepository.getShape(shapeId: shapeId)
        })
    }

    func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] {
        try await execute(local: {
            try await localRepository.getAllRoutes(limit: limit, offset: offset)
        }, remote: {
            try await remoteRepository.getAllRoutes(limit: limit, offset: offset)
        })
    }

    func planTrip(origin: Location, destination: Location, maxAlternatives: Int, rankingPriority: String) async throws -> TripPlan {
        try await execute(local: {
            try await localRepository.planTrip(
                origin: origin,
                destination: destination,
                maxAlternatives: maxAlternatives,
                rankingPriority: rankingPriority
            )
        }, remote: {
            try await remoteRepository.planTrip(
                origin: origin,
                destination: destination,
                maxAlternatives: maxAlternatives,
                rankingPriority: rankingPriority
            )
        })
    }

    private func execute<T>(
        local: () async throws -> T,
        remote: () async throws -> T
    ) async throws -> T {
        guard shouldUseLocalData else {
            return try await remote()
        }

        do {
            return try await local()
        } catch LocalTransitRepositoryError.noImportedData {
            return try await remote()
        } catch LocalTransitRepositoryError.unsupportedLocalOperation {
            return try await remote()
        }
    }

    private var shouldUseLocalData: Bool {
        modeService.useLocalData && feedService.getCurrentFeed() != nil
    }
}
