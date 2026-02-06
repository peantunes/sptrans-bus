import XCTest
@testable import sp_trains_bus
import zlib

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

    func testGTFSImporterPopulatesLocalRepository() async throws {
        let container = LocalDataModelContainer.make(inMemory: true)
        let feedService = GTFSFeedService(modelContainer: container)
        let importer = GTFSImporterService(modelContainer: container, feedService: feedService, batchSize: 1)
        let localRepository = LocalTransitRepository(modelContainer: container)
        let fixtureDirectory = try makeGTFSFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: fixtureDirectory) }

        let importedFeed = try await importer.importFromDirectory(fixtureDirectory, sourceURL: "https://example.com/gtfs.zip")
        XCTAssertFalse(importedFeed.versionIdentifier.isEmpty)
        XCTAssertNotNil(feedService.getCurrentFeed())

        let searchedStops = try await localRepository.searchStops(query: "Central", limit: 10)
        XCTAssertEqual(searchedStops.count, 1)
        XCTAssertEqual(searchedStops.first?.stopId, 100)

        let nearbyStops = try await localRepository.getNearbyStops(location: Location(latitude: -23.55, longitude: -46.63), limit: 1)
        XCTAssertEqual(nearbyStops.first?.stopId, 100)

        let arrivals = try await localRepository.getArrivals(stopId: 100, limit: 5)
        XCTAssertFalse(arrivals.isEmpty)
        XCTAssertEqual(arrivals.first?.routeId, "R1")

        let tripStop = try await localRepository.getTrip(tripId: "TRIP1")
        XCTAssertEqual(tripStop.stops.count, 2)

        let shape = try await localRepository.getShape(shapeId: "S1")
        XCTAssertEqual(shape.count, 2)
    }

    func testConfigurableTransitRepositorySwitchesBetweenRemoteAndLocal() async throws {
        let container = LocalDataModelContainer.make(inMemory: true)
        let feedService = GTFSFeedService(modelContainer: container)
        let suiteName = "TransitModeTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let modeService = UserDefaultsTransitDataModeService(userDefaults: userDefaults)
        modeService.useLocalData = true

        let localStop = Stop(
            stopId: 1,
            stopName: "Local Stop",
            location: Location(latitude: 0, longitude: 0),
            stopSequence: 0,
            stopCode: "L1",
            wheelchairBoarding: 0
        )
        let remoteStop = Stop(
            stopId: 2,
            stopName: "Remote Stop",
            location: Location(latitude: 1, longitude: 1),
            stopSequence: 0,
            stopCode: "R1",
            wheelchairBoarding: 0
        )

        let localRepository = StubTransitRepository(stops: [localStop])
        let remoteRepository = StubTransitRepository(stops: [remoteStop])
        let repository = ConfigurableTransitRepository(
            remoteRepository: remoteRepository,
            localRepository: localRepository,
            modeService: modeService,
            feedService: feedService
        )

        // Local mode is enabled but there is no imported feed metadata yet.
        let beforeFeedStops = try await repository.getNearbyStops(location: .saoPaulo, limit: 1)
        XCTAssertEqual(beforeFeedStops.first?.stopId, 2)

        feedService.updateFeed(
            GTFSFeedInfo(
                versionIdentifier: "v1",
                sourceURL: nil,
                localArchivePath: "/tmp",
                downloadedAt: Date(),
                lastCheckedAt: Date(),
                etag: nil,
                lastModified: nil
            )
        )

        let localModeStops = try await repository.getNearbyStops(location: .saoPaulo, limit: 1)
        XCTAssertEqual(localModeStops.first?.stopId, 1)

        modeService.useLocalData = false
        let remoteModeStops = try await repository.getNearbyStops(location: .saoPaulo, limit: 1)
        XCTAssertEqual(remoteModeStops.first?.stopId, 2)
    }

    func testImportUseCaseEnablesLocalMode() async throws {
        let container = LocalDataModelContainer.make(inMemory: true)
        let feedService = GTFSFeedService(modelContainer: container)
        let importer = GTFSImporterService(modelContainer: container, feedService: feedService, batchSize: 1)
        let suiteName = "TransitImportMode-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let modeService = UserDefaultsTransitDataModeService(userDefaults: userDefaults)
        let useCase = ImportGTFSDataUseCase(importService: importer, modeService: modeService)
        let fixtureDirectory = try makeGTFSFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: fixtureDirectory) }

        XCTAssertFalse(modeService.useLocalData)
        _ = try await useCase.execute(from: fixtureDirectory, feedSourceURL: nil)
        XCTAssertTrue(modeService.useLocalData)
    }

    func testImportUseCaseAcceptsZipArchive() async throws {
        let container = LocalDataModelContainer.make(inMemory: true)
        let feedService = GTFSFeedService(modelContainer: container)
        let importer = GTFSImporterService(modelContainer: container, feedService: feedService, batchSize: 1)
        let suiteName = "TransitImportZip-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let modeService = UserDefaultsTransitDataModeService(userDefaults: userDefaults)
        let useCase = ImportGTFSDataUseCase(importService: importer, modeService: modeService)
        let fixtureDirectory = try makeGTFSFixtureDirectory()
        let archiveURL = try makeZipArchive(from: fixtureDirectory)
        defer {
            try? FileManager.default.removeItem(at: fixtureDirectory)
            try? FileManager.default.removeItem(at: archiveURL)
        }

        XCTAssertFalse(modeService.useLocalData)
        _ = try await useCase.execute(from: archiveURL, feedSourceURL: archiveURL.absoluteString)
        XCTAssertTrue(modeService.useLocalData)

        let repository = LocalTransitRepository(modelContainer: container)
        let searchedStops = try await repository.searchStops(query: "Central", limit: 10)
        XCTAssertEqual(searchedStops.first?.stopId, 100)
    }

    private func makeGTFSFixtureDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("gtfs-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        try write(
            """
            stop_id,stop_code,stop_name,stop_lat,stop_lon,wheelchair_boarding
            100,100,Central Stop,-23.55,-46.63,1
            101,101,South Stop,-23.56,-46.64,0
            """,
            to: directoryURL.appendingPathComponent("stops.txt")
        )

        try write(
            """
            route_id,agency_id,route_short_name,route_long_name,route_desc,route_type,route_color,route_text_color
            R1,1,10,Route 10,,3,509E2F,FFFFFF
            """,
            to: directoryURL.appendingPathComponent("routes.txt")
        )

        try write(
            """
            route_id,service_id,trip_id,trip_headsign,direction_id,shape_id
            R1,WEEK,TRIP1,Downtown,0,S1
            """,
            to: directoryURL.appendingPathComponent("trips.txt")
        )

        try write(
            """
            trip_id,arrival_time,departure_time,stop_id,stop_sequence
            TRIP1,27:00:00,27:00:00,100,1
            TRIP1,27:10:00,27:10:00,101,2
            """,
            to: directoryURL.appendingPathComponent("stop_times.txt")
        )

        try write(
            """
            shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence
            S1,-23.55,-46.63,1
            S1,-23.56,-46.64,2
            """,
            to: directoryURL.appendingPathComponent("shapes.txt")
        )

        try write(
            """
            service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date
            WEEK,1,1,1,1,1,1,1,20200101,20991231
            """,
            to: directoryURL.appendingPathComponent("calendar.txt")
        )

        return directoryURL
    }

    private func makeZipArchive(from directoryURL: URL) throws -> URL {
        let fileNames = [
            "stops.txt",
            "routes.txt",
            "trips.txt",
            "stop_times.txt",
            "shapes.txt",
            "calendar.txt"
        ]

        let entries = try fileNames.map { fileName in
            let fileURL = directoryURL.appendingPathComponent(fileName)
            return (fileName, try Data(contentsOf: fileURL))
        }

        let archiveData = try makeStoredZipArchive(entries: entries)
        let archiveURL = FileManager.default.temporaryDirectory.appendingPathComponent("gtfs-fixture-\(UUID().uuidString).zip")
        try archiveData.write(to: archiveURL, options: .atomic)
        return archiveURL
    }

    private func makeStoredZipArchive(entries: [(String, Data)]) throws -> Data {
        struct CentralEntry {
            let nameData: Data
            let crc: UInt32
            let size: UInt32
            let localHeaderOffset: UInt32
        }

        var archive = Data()
        var centralEntries: [CentralEntry] = []
        centralEntries.reserveCapacity(entries.count)

        for (name, content) in entries {
            guard let nameData = name.data(using: .utf8) else {
                throw NSError(domain: "LocalDataServicesTests", code: 1)
            }

            let localOffset = UInt32(archive.count)
            let size = UInt32(content.count)
            let crc = content.withUnsafeBytes { buffer -> UInt32 in
                guard let baseAddress = buffer.baseAddress else { return 0 }
                return UInt32(crc32(0, baseAddress.assumingMemoryBound(to: Bytef.self), uInt(buffer.count)))
            }

            appendUInt32LE(0x04034B50, to: &archive)
            appendUInt16LE(20, to: &archive) // version needed
            appendUInt16LE(0, to: &archive) // flags
            appendUInt16LE(0, to: &archive) // compression method (stored)
            appendUInt16LE(0, to: &archive) // mod time
            appendUInt16LE(0, to: &archive) // mod date
            appendUInt32LE(crc, to: &archive)
            appendUInt32LE(size, to: &archive)
            appendUInt32LE(size, to: &archive)
            appendUInt16LE(UInt16(nameData.count), to: &archive)
            appendUInt16LE(0, to: &archive) // extra length
            archive.append(nameData)
            archive.append(content)

            centralEntries.append(
                CentralEntry(
                    nameData: nameData,
                    crc: crc,
                    size: size,
                    localHeaderOffset: localOffset
                )
            )
        }

        let centralDirectoryOffset = UInt32(archive.count)

        for entry in centralEntries {
            appendUInt32LE(0x02014B50, to: &archive)
            appendUInt16LE(20, to: &archive) // version made by
            appendUInt16LE(20, to: &archive) // version needed
            appendUInt16LE(0, to: &archive) // flags
            appendUInt16LE(0, to: &archive) // compression method
            appendUInt16LE(0, to: &archive) // mod time
            appendUInt16LE(0, to: &archive) // mod date
            appendUInt32LE(entry.crc, to: &archive)
            appendUInt32LE(entry.size, to: &archive)
            appendUInt32LE(entry.size, to: &archive)
            appendUInt16LE(UInt16(entry.nameData.count), to: &archive)
            appendUInt16LE(0, to: &archive) // extra length
            appendUInt16LE(0, to: &archive) // comment length
            appendUInt16LE(0, to: &archive) // disk number start
            appendUInt16LE(0, to: &archive) // internal attrs
            appendUInt32LE(0, to: &archive) // external attrs
            appendUInt32LE(entry.localHeaderOffset, to: &archive)
            archive.append(entry.nameData)
        }

        let centralDirectorySize = UInt32(archive.count) - centralDirectoryOffset

        appendUInt32LE(0x06054B50, to: &archive)
        appendUInt16LE(0, to: &archive) // number of this disk
        appendUInt16LE(0, to: &archive) // start disk
        appendUInt16LE(UInt16(centralEntries.count), to: &archive)
        appendUInt16LE(UInt16(centralEntries.count), to: &archive)
        appendUInt32LE(centralDirectorySize, to: &archive)
        appendUInt32LE(centralDirectoryOffset, to: &archive)
        appendUInt16LE(0, to: &archive) // comment length

        return archive
    }

    private func appendUInt16LE(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0x00FF))
        data.append(UInt8((value & 0xFF00) >> 8))
    }

    private func appendUInt32LE(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0x000000FF))
        data.append(UInt8((value & 0x0000FF00) >> 8))
        data.append(UInt8((value & 0x00FF0000) >> 16))
        data.append(UInt8((value & 0xFF000000) >> 24))
    }

    private func write(_ content: String, to fileURL: URL) throws {
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

private final class StubTransitRepository: TransitRepositoryProtocol {
    private let stops: [Stop]

    init(stops: [Stop]) {
        self.stops = stops
    }

    func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] {
        Array(stops.prefix(limit))
    }

    func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] { [] }

    func searchStops(query: String, limit: Int) async throws -> [Stop] { [] }

    func getTrip(tripId: String) async throws -> TripStop {
        TripStop(
            trip: Trip(routeId: "R", serviceId: "S", tripId: "T", tripHeadsign: "", directionId: 0, shapeId: ""),
            stops: []
        )
    }

    func getRoute(routeId: String) async throws -> Route {
        Route(
            routeId: routeId,
            agencyId: 0,
            routeShortName: "",
            routeLongName: "",
            routeDesc: "",
            routeType: 3,
            routeColor: "000000",
            routeTextColor: "FFFFFF"
        )
    }

    func getShape(shapeId: String) async throws -> [Location] { [] }

    func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] { [] }

    func planTrip(origin: Location, destination: Location, maxAlternatives: Int, rankingPriority: String) async throws -> TripPlan {
        TripPlan(alternatives: [], rankingPriority: rankingPriority)
    }
}
