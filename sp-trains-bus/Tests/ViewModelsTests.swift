import XCTest
import Combine
@testable import sp_trains_bus

class ViewModelsTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        cancellables = []
    }

    override func tearDownWithError() throws {
        cancellables = nil
    }

    // MARK: - HomeViewModel Tests

    func testHomeViewModelLoadDataSuccess() async throws {
        let mockGetNearbyStopsUseCase = MockGetNearbyStopsUseCase()
        let mockLocationService = MockLocationService()
        let mockStorageService = MockStorageService()

        mockLocationService.currentLocation = Location(latitude: 1.0, longitude: 1.0)
        mockGetNearbyStopsUseCase.stopsToReturn = [Stop(stopId: "1", stopName: "Test Stop", location: Location(latitude: 1.0, longitude: 1.0), stopSequence: 0, stopCode: "", wheelchairBoarding: 0)]

        let viewModel = HomeViewModel(getNearbyStopsUseCase: mockGetNearbyStopsUseCase, locationService: mockLocationService, storageService: mockStorageService)

        let expectation = XCTestExpectation(description: "HomeViewModel loads data")

        viewModel.$nearbyStops
            .dropFirst() // Ignore initial empty array
            .sink { stops in
                XCTAssertEqual(stops.count, 1)
                XCTAssertEqual(stops.first?.stopName, "Test Stop")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.loadData()

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testHomeViewModelLoadDataFailure() async throws {
        let mockGetNearbyStopsUseCase = MockGetNearbyStopsUseCase()
        let mockLocationService = MockLocationService()
        let mockStorageService = MockStorageService()

        mockLocationService.currentLocation = Location(latitude: 1.0, longitude: 1.0)
        mockGetNearbyStopsUseCase.shouldThrowError = true

        let viewModel = HomeViewModel(getNearbyStopsUseCase: mockGetNearbyStopsUseCase, locationService: mockLocationService, storageService: mockStorageService)

        let expectation = XCTestExpectation(description: "HomeViewModel handles error")

        viewModel.$errorMessage
            .dropFirst()
            .sink { message in
                XCTAssertNotNil(message)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.loadData()

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - StopDetailViewModel Tests

    func testStopDetailViewModelLoadArrivalsSuccess() async throws {
        let mockGetArrivalsUseCase = MockGetArrivalsUseCase()
        mockGetArrivalsUseCase.arrivalsToReturn = [Arrival(tripId: "T1", arrivalTime: "10:00", departureTime: "10:01", stopId: "1", stopSequence: 1, stopHeadsign: "Dest", pickupType: 0, dropOffType: 0, shapeDistTraveled: "", frequency: nil, waitTime: 5)]

        let stop = Stop(stopId: "1", stopName: "Test Stop", location: Location(latitude: 0, longitude: 0), stopSequence: 0, stopCode: "", wheelchairBoarding: 0)
        let viewModel = StopDetailViewModel(stop: stop, getArrivalsUseCase: mockGetArrivalsUseCase)

        let expectation = XCTestExpectation(description: "StopDetailViewModel loads arrivals")

        viewModel.$arrivals
            .dropFirst()
            .sink { arrivals in
                XCTAssertEqual(arrivals.count, 1)
                XCTAssertEqual(arrivals.first?.tripId, "T1")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.loadArrivals()

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - SystemStatusViewModel Tests

    func testSystemStatusViewModelLoadMetroStatus() {
        let mockGetMetroStatusUseCase = MockGetMetroStatusUseCase()
        let viewModel = SystemStatusViewModel(getMetroStatusUseCase: mockGetMetroStatusUseCase)

        let expectation = XCTestExpectation(description: "SystemStatusViewModel loads metro status")
        
        viewModel.$metroLines
            .dropFirst()
            .sink { lines in
                XCTAssertFalse(lines.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.loadMetroStatus()

        wait(for: [expectation], timeout: 2.0) // Allow for DispatchQueue.main.asyncAfter
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.overallStatus, "Normal Operation")
    }

    // MARK: - MapExplorerViewModel Tests

    func testMapExplorerViewModelLoadStopsSuccess() async throws {
        let mockGetNearbyStopsUseCase = MockGetNearbyStopsUseCase()
        let mockLocationService = MockLocationService()
        mockLocationService.currentLocation = Location(latitude: -23.0, longitude: -46.0)
        mockGetNearbyStopsUseCase.stopsToReturn = [Stop(stopId: "1", stopName: "Map Stop", location: Location(latitude: -23.0, longitude: -46.0), stopSequence: 0, stopCode: "", wheelchairBoarding: 0)]

        let viewModel = MapExplorerViewModel(getNearbyStopsUseCase: mockGetNearbyStopsUseCase, locationService: mockLocationService)

        let expectation = XCTestExpectation(description: "MapExplorerViewModel loads stops")

        viewModel.$stops
            .dropFirst()
            .sink { stops in
                XCTAssertEqual(stops.count, 1)
                XCTAssertEqual(stops.first?.stopName, "Map Stop")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.loadStopsInVisibleRegion()

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - SearchViewModel Tests

    func testSearchViewModelPerformSearchSuccess() async throws {
        let mockSearchStopsUseCase = MockSearchStopsUseCase()
        mockSearchStopsUseCase.stopsToReturn = [Stop(stopId: "1", stopName: "Search Result", location: Location(latitude: 0, longitude: 0), stopSequence: 0, stopCode: "", wheelchairBoarding: 0)]

        let viewModel = SearchViewModel(searchStopsUseCase: mockSearchStopsUseCase)

        let expectation = XCTestExpectation(description: "SearchViewModel performs search")

        viewModel.$searchResults
            .dropFirst()
            .sink { results in
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(results.first?.stopName, "Search Result")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.searchText = "query" // Trigger search

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Mock Use Cases for ViewModel Testing

    class MockGetNearbyStopsUseCase: GetNearbyStopsUseCase {
        var stopsToReturn: [Stop] = []
        var shouldThrowError: Bool = false

        override func execute(limit: Int = 10) async throws -> [Stop] {
            if shouldThrowError {
                throw TestError.forcedError
            }
            return stopsToReturn
        }
    }

    class MockGetArrivalsUseCase: GetArrivalsUseCase {
        var arrivalsToReturn: [Arrival] = []
        var shouldThrowError: Bool = false

        override func execute(stopId: String, limit: Int = 10) async throws -> [Arrival] {
            if shouldThrowError {
                throw TestError.forcedError
            }
            return arrivalsToReturn
        }
    }

    class MockSearchStopsUseCase: SearchStopsUseCase {
        var stopsToReturn: [Stop] = []
        var shouldThrowError: Bool = false

        override func execute(query: String, limit: Int = 10) async throws -> [Stop] {
            if shouldThrowError {
                throw TestError.forcedError
            }
            return stopsToReturn
        }
    }

    class MockGetMetroStatusUseCase: GetMetroStatusUseCase {
        override func execute() -> [MetroLine] {
            return [MetroLine(line: "L1", name: "Azul", colorHex: "0000FF")]
        }
    }
}
