import XCTest
@testable import sp_trains_bus

class UseCasesTests: XCTestCase {

    // MARK: - Mocks for Protocols

    class MockTransitRepository: TransitRepositoryProtocol {
        var nearbyStopsResult: Result<[Stop], Error> = .success([])
        var arrivalsResult: Result<[Arrival], Error> = .success([])
        var searchStopsResult: Result<[Stop], Error> = .success([])
        var tripResult: Result<TripStop, Error> = .failure(TestError.notImplemented)
        var routeResult: Result<Route, Error> = .failure(TestError.notImplemented)
        var shapeResult: Result<[Location], Error> = .success([])
        var allRoutesResult: Result<[Route], Error> = .success([])

        func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] {
            return try nearbyStopsResult.get()
        }
        func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] {
            return try arrivalsResult.get()
        }
        func searchStops(query: String, limit: Int) async throws -> [Stop] {
            return try searchStopsResult.get()
        }
        func getTrip(tripId: String) async throws -> TripStop {
            return try tripResult.get()
        }
        func getRoute(routeId: String) async throws -> Route {
            return try routeResult.get()
        }
        func getShape(shapeId: String) async throws -> [Location] {
            return try shapeResult.get()
        }
        func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] {
            return try allRoutesResult.get()
        }
    }

    class MockLocationService: LocationServiceProtocol {
        var currentLocation: Location?
        var permissionStatus: Bool = false

        func requestLocationPermission() {
            permissionStatus = true
        }
        func getCurrentLocation() -> Location? {
            return currentLocation
        }
        func startUpdatingLocation() {}
        func stopUpdatingLocation() {}
    }

    enum TestError: Error {
        case notImplemented
        case forcedError
    }

    // MARK: - GetNearbyStopsUseCase Tests

    func testGetNearbyStopsUseCaseSuccess() async throws {
        let mockRepo = MockTransitRepository()
        let mockLocationService = MockLocationService()
        mockLocationService.currentLocation = Location(latitude: 1.0, longitude: 1.0)
        mockRepo.nearbyStopsResult = .success([Stop(stopId: 1, stopName: "Test Stop", location: Location(latitude: 1.0, longitude: 1.0), stopSequence: 0, stopCode: "", wheelchairBoarding: 0)])

        let useCase = GetNearbyStopsUseCase(transitRepository: mockRepo, locationService: mockLocationService)
        let stops = try await useCase.execute(limit: 1)

        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops.first?.stopName, "Test Stop")
    }

    func testGetNearbyStopsUseCaseLocationUnavailable() async {
        let mockRepo = MockTransitRepository()
        let mockLocationService = MockLocationService()
        mockLocationService.currentLocation = nil // Simulate no location

        let useCase = GetNearbyStopsUseCase(transitRepository: mockRepo, locationService: mockLocationService)

        do {
            _ = try await useCase.execute(limit: 1)
            XCTFail("Expected LocationError.locationUnavailable but got success")
        } catch let error as LocationError {
            XCTAssertEqual(error, LocationError.locationUnavailable)
        } catch {
            XCTFail("Expected LocationError.locationUnavailable but got \(error)")
        }
    }

    // MARK: - GetArrivalsUseCase Tests

    func testGetArrivalsUseCaseSuccess() async throws {
        let mockRepo = MockTransitRepository()
        mockRepo.arrivalsResult = .success([Arrival(tripId: "T1", routeId: "R1", routeShortName: "R1", routeLongName: "Route 1", headsign: "Dest", arrivalTime: "10:00", departureTime: "10:01", stopId: 1, stopSequence: 1, routeType: 3, routeColor: "FF0000", routeTextColor: "FFFFFF", frequency: nil, waitTime: 5)])

        let useCase = GetArrivalsUseCase(transitRepository: mockRepo)
        let arrivals = try await useCase.execute(stopId: 1, limit: 1)

        XCTAssertEqual(arrivals.count, 1)
        XCTAssertEqual(arrivals.first?.tripId, "T1")
    }

    // MARK: - SearchStopsUseCase Tests

    func testSearchStopsUseCaseSuccess() async throws {
        let mockRepo = MockTransitRepository()
        mockRepo.searchStopsResult = .success([Stop(stopId: 1, stopName: "Search Stop", location: Location(latitude: 1.0, longitude: 1.0), stopSequence: 0, stopCode: "", wheelchairBoarding: 0)])

        let useCase = SearchStopsUseCase(transitRepository: mockRepo)
        let stops = try await useCase.execute(query: "Search", limit: 1)

        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops.first?.stopName, "Search Stop")
    }

    // MARK: - GetTripRouteUseCase Tests

    func testGetTripRouteUseCaseSuccess() async throws {
        let mockRepo = MockTransitRepository()
        let trip = Trip(routeId: "R1", serviceId: "S1", tripId: "T1", tripHeadsign: "Dest", directionId: 0, shapeId: "SH1")
        mockRepo.tripResult = .success(TripStop(trip: trip, stops: []))

        let useCase = GetTripRouteUseCase(transitRepository: mockRepo)
        let trip = try await useCase.execute(tripId: "T1")

        XCTAssertEqual(trip.trip.tripId, "T1")
    }

    // MARK: - GetRouteShapeUseCase Tests

    func testGetRouteShapeUseCaseSuccess() async throws {
        let mockRepo = MockTransitRepository()
        mockRepo.shapeResult = .success([Location(latitude: 1.0, longitude: 1.0)])

        let useCase = GetRouteShapeUseCase(transitRepository: mockRepo)
        let shape = try await useCase.execute(shapeId: "SH1")

        XCTAssertEqual(shape.count, 1)
        XCTAssertEqual(shape.first?.latitude, 1.0)
    }

    // MARK: - GetMetroStatusUseCase Tests

    func testGetMetroStatusUseCaseReturnsData() {
        let useCase = GetMetroStatusUseCase()
        let metroLines = useCase.execute()

        XCTAssertFalse(metroLines.isEmpty)
        XCTAssertEqual(metroLines.count, 12)
    }
}
