import XCTest
@testable import sp_trains_bus

final class LocalDataServicesTests: XCTestCase {

    func testSwiftDataStorageSavesAndFiltersPlaces() {
        let container = LocalDataModelContainer.make(inMemory: true)
        let storage = SwiftDataStorageService(modelContainer: container)

        let home = UserPlace(name: "Apartment", location: Location(latitude: 1.1, longitude: 2.2), type: .home)
        let study = UserPlace(name: "Library", location: Location(latitude: 3.3, longitude: 4.4), type: .study)

        storage.savePlace(home)
        storage.savePlace(study)

        let allPlaces = storage.getSavedPlaces()
        let studyPlaces = storage.getPlaces(type: .study)

        XCTAssertEqual(allPlaces.count, 2)
        XCTAssertEqual(studyPlaces.count, 1)
        XCTAssertEqual(studyPlaces.first?.name, "Library")
    }

    func testGTFSFeedServiceWeeklyCheckPolicy() {
        let container = LocalDataModelContainer.make(inMemory: true)
        let service = GTFSFeedService(modelContainer: container)
        let now = Date()

        XCTAssertTrue(service.shouldCheckForWeeklyUpdate(asOf: now))

        service.updateFeed(
            GTFSFeedInfo(
                versionIdentifier: "v1",
                sourceURL: "https://example.com/feed.zip",
                localArchivePath: "/tmp/feed.zip",
                downloadedAt: now,
                lastCheckedAt: now,
                etag: "123",
                lastModified: nil
            )
        )

        let sixDaysLater = Calendar.current.date(byAdding: .day, value: 6, to: now)!
        let eightDaysLater = Calendar.current.date(byAdding: .day, value: 8, to: now)!

        XCTAssertFalse(service.shouldCheckForWeeklyUpdate(asOf: sixDaysLater))
        XCTAssertTrue(service.shouldCheckForWeeklyUpdate(asOf: eightDaysLater))
    }
}
