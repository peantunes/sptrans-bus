import XCTest
@testable import sp_trains_bus // Assuming the main module name

class ServiceLayerTests: XCTestCase {

    var userDefaultsStorageService: UserDefaultsStorageService!
    var mockUserDefaults: UserDefaults!

    override func setUpWithError() throws {
        mockUserDefaults = UserDefaults(suiteName: #file)
        userDefaultsStorageService = UserDefaultsStorageService(userDefaults: mockUserDefaults)
    }

    override func tearDownWithError() throws {
        mockUserDefaults.removePersistentDomain(forName: #file)
        userDefaultsStorageService = nil
        mockUserDefaults = nil
    }

    func testSaveAndGetFavoriteStops() {
        let location = Location(latitude: 1.0, longitude: 2.0)
        let stop1 = Stop(stopId: 1, stopName: "Stop 1", location: location, stopSequence: 1, stopCode: "S1", wheelchairBoarding: 0)
        let stop2 = Stop(stopId: 2, stopName: "Stop 2", location: location, stopSequence: 2, stopCode: "S2", wheelchairBoarding: 1)

        userDefaultsStorageService.saveFavorite(stop: stop1)
        userDefaultsStorageService.saveFavorite(stop: stop2)

        let favorites = userDefaultsStorageService.getFavoriteStops()
        XCTAssertEqual(favorites.count, 2)
        XCTAssertTrue(favorites.contains(where: { $0.stopId == 1 }))
        XCTAssertTrue(favorites.contains(where: { $0.stopId == 2 }))
    }

    func testRemoveFavoriteStop() {
        let location = Location(latitude: 1.0, longitude: 2.0)
        let stop1 = Stop(stopId: 1, stopName: "Stop 1", location: location, stopSequence: 1, stopCode: "S1", wheelchairBoarding: 0)
        let stop2 = Stop(stopId: 2, stopName: "Stop 2", location: location, stopSequence: 2, stopCode: "S2", wheelchairBoarding: 1)

        userDefaultsStorageService.saveFavorite(stop: stop1)
        userDefaultsStorageService.saveFavorite(stop: stop2)
        userDefaultsStorageService.removeFavorite(stop: stop1)

        let favorites = userDefaultsStorageService.getFavoriteStops()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertFalse(favorites.contains(where: { $0.stopId == 1 }))
        XCTAssertTrue(favorites.contains(where: { $0.stopId == 2 }))
    }

    func testSaveAndGetHomeLocation() {
        let homeLocation = Location(latitude: 3.0, longitude: 4.0)
        userDefaultsStorageService.saveHome(location: homeLocation)
        let retrievedLocation = userDefaultsStorageService.getHomeLocation()

        XCTAssertEqual(retrievedLocation?.latitude, 3.0)
        XCTAssertEqual(retrievedLocation?.longitude, 4.0)
    }

    func testSaveAndGetWorkLocation() {
        let workLocation = Location(latitude: 5.0, longitude: 6.0)
        userDefaultsStorageService.saveWork(location: workLocation)
        let retrievedLocation = userDefaultsStorageService.getWorkLocation()

        XCTAssertEqual(retrievedLocation?.latitude, 5.0)
        XCTAssertEqual(retrievedLocation?.longitude, 6.0)
    }
}