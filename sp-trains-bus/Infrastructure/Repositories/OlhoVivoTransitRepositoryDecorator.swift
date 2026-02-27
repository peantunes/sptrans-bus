import Foundation

final class OlhoVivoTransitRepositoryDecorator: TransitRepositoryProtocol {
    private let baseRepository: TransitRepositoryProtocol
    private let olhoVivoService: OlhoVivoArrivalsProviding?
    private let stateLock = NSLock()
    private var isOlhoVivoDisabledForAppSession = false

    init(
        baseRepository: TransitRepositoryProtocol,
        olhoVivoService: OlhoVivoArrivalsProviding?
    ) {
        self.baseRepository = baseRepository
        self.olhoVivoService = olhoVivoService
    }

    func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] {
        try await baseRepository.getNearbyStops(location: location, limit: limit)
    }

    func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] {
        if isOlhoVivoDisabled() {
            return try await baseRepository.getArrivals(stopId: stopId, limit: limit)
        }

        if let olhoVivoService {
            do {
                let liveArrivals = try await olhoVivoService.getArrivals(for: stopId, limit: limit)
                if !liveArrivals.isEmpty {
                    #if DEBUG
                    print("Olho Vivo live arrivals used for stop \(stopId): \(liveArrivals.count)")
                    #endif
                    return liveArrivals
                }
            } catch let error as OlhoVivoServiceError {
                if error.isBlocking403 {
                    disableOlhoVivoForSession()
                    #if DEBUG
                    print("Olho Vivo disabled for this app session after 403 response.")
                    #endif
                }

                #if DEBUG
                print("Olho Vivo unavailable for stop \(stopId), fallback to base repository: \(error.localizedDescription)")
                #endif
            } catch {
                #if DEBUG
                print("Olho Vivo unavailable for stop \(stopId), fallback to base repository: \(error.localizedDescription)")
                #endif
            }
        }

        return try await baseRepository.getArrivals(stopId: stopId, limit: limit)
    }

    func searchStops(query: String, limit: Int) async throws -> [Stop] {
        try await baseRepository.searchStops(query: query, limit: limit)
    }

    func getTrip(tripId: String) async throws -> TripStop {
        try await baseRepository.getTrip(tripId: tripId)
    }

    func getRoute(routeId: String) async throws -> Route {
        try await baseRepository.getRoute(routeId: routeId)
    }

    func getShape(shapeId: String) async throws -> [Location] {
        try await baseRepository.getShape(shapeId: shapeId)
    }

    func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] {
        try await baseRepository.getAllRoutes(limit: limit, offset: offset)
    }

    func planTrip(origin: Location, destination: Location, maxAlternatives: Int, rankingPriority: String) async throws -> TripPlan {
        try await baseRepository.planTrip(
            origin: origin,
            destination: destination,
            maxAlternatives: maxAlternatives,
            rankingPriority: rankingPriority
        )
    }

    private func isOlhoVivoDisabled() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isOlhoVivoDisabledForAppSession
    }

    private func disableOlhoVivoForSession() {
        stateLock.lock()
        isOlhoVivoDisabledForAppSession = true
        stateLock.unlock()
    }
}
