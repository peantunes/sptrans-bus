import XCTest
@testable import sp_trains_bus

final class JourneyPlannerTests: XCTestCase {
    private func decode(_ fixture: String = "planner-multimodal") throws -> TripPlan {
        let url = Bundle.module.url(forResource: fixture, withExtension: "json", subdirectory: "Fixtures")!
        return try JSONDecoder().decode(PlanResponse.self, from: Data(contentsOf: url)).result.toDomain()
    }

    func testDoorToDoorTimesAndAllModesSurviveMapping() throws {
        let alternative = try XCTUnwrap(decode().alternatives.first)
        XCTAssertEqual(alternative.legs.map(\.mode), ["bus", "metro", "rail"])
        XCTAssertEqual(alternative.transfers, 2)
        XCTAssertEqual(alternative.durationMinutes, 50)
        XCTAssertEqual(alternative.walkMeters, 720)
        XCTAssertEqual(alternative.displayDepartureTime, "23:50")
        XCTAssertEqual(alternative.displayArrivalTime, "00:40 (+1d)")
        XCTAssertEqual(alternative.legs[1].headsign, "Terminal 1")
        XCTAssertEqual(alternative.legs[1].intermediateStops?.map(\.stopId), [5])
    }

    @MainActor
    func testWalkingTransfersKeepServerOrderAndShortWalks() throws {
        let alternative = try XCTUnwrap(decode().alternatives.first)
        let model = detail(alternative)
        XCTAssertEqual(model.legs.count, 3)
        XCTAssertEqual(model.combinedSegments.map(\.isWalking), [true, false, true, false, true, false, true])
        let walks = model.segments.compactMap { segment -> TripPlanWalkSegment? in
            guard case .walk(let walk) = segment else { return nil }
            return walk
        }
        XCTAssertEqual(walks.map(\.distanceMeters), [50, 200, 400, 70])
        XCTAssertEqual(walks.map(\.durationMinutes), [1, 3, 5, 1])
        XCTAssertEqual(model.legs[1].stops.map(\.stopId), [4, 5, 6])
        XCTAssertEqual(model.combinedSegments[2].coordinates, [walks[1].fromLocation, walks[1].toLocation])
    }

    @MainActor
    func testPlannerStopsAndMapSurviveDetailNetworkFailure() async throws {
        let alternative = try XCTUnwrap(decode().alternatives.first)
        let model = detail(alternative)
        await model.load()
        XCTAssertEqual(model.legs[0].stops.map(\.stopId), [1, 2, 3])
        XCTAssertTrue(model.legs.allSatisfy { !$0.isLoading && $0.errorMessage == nil })
        XCTAssertEqual(model.combinedSegments.count, 7)
    }

    @MainActor
    func testWalkingOnlyNeedsNoTransitAndHasMap() async throws {
        let alternative = try XCTUnwrap(decode().walkingAlternative)
        let model = detail(alternative)
        await model.load()
        XCTAssertEqual(alternative.type, .walk)
        XCTAssertEqual(alternative.durationMinutes, 22)
        XCTAssertEqual(alternative.displayArrivalTime, "00:12 (+1d)")
        XCTAssertTrue(model.legs.isEmpty)
        XCTAssertEqual(model.combinedSegments.count, 1)
        XCTAssertTrue(model.combinedSegments[0].isWalking)
        XCTAssertEqual(model.combinedSegments[0].coordinates.count, 2)
    }

    func testWalkOnlyResponseWithoutTransitOptions() throws {
        let json = #"{"result":{"alternatives":[],"origin":{"lat":-23.55,"lon":-46.63},"destination":{"lat":-23.551,"lon":-46.631},"departure":{"time":"08:30:00"},"walk":{"distanceMeters":150,"durationMinutes":3,"arrivalTime":"08:33:00"}}}"#
        let plan = try JSONDecoder().decode(PlanResponse.self, from: Data(json.utf8)).result.toDomain()
        XCTAssertTrue(plan.alternatives.isEmpty)
        XCTAssertEqual(plan.walkingAlternative?.durationMinutes, 3)
    }

    @MainActor
    func testLegacyResponseBuildsTwoLegsWithoutNewFields() throws {
        let plan = try decode("planner-legacy")
        let alternative = try XCTUnwrap(plan.alternatives.first)
        XCTAssertNil(plan.walkingAlternative)
        XCTAssertNil(alternative.durationMinutes)
        XCTAssertTrue(alternative.segments.isEmpty)
        XCTAssertEqual(detail(alternative).legs.count, 2)
        XCTAssertEqual(alternative.transfers, 1)
    }

    func testEmptyResponseDecodesWithoutWalkingOption() throws {
        let plan = try JSONDecoder().decode(PlanResponse.self, from: Data(#"{"result":{"alternatives":[]}}"#.utf8)).result.toDomain()
        XCTAssertTrue(plan.alternatives.isEmpty)
        XCTAssertNil(plan.walkingAlternative)
    }

    func testDepartureUsesSaoPauloDateEvenAcrossUTCMidnight() throws {
        let departure = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-17T01:30:00Z"))
        let endpoint = TransitAPIEndpoint.plan(origin: .saoPaulo, destination: .saoPaulo,
            maxAlternatives: 5, rankingPriority: "least_walking",
            options: TripPlanningOptions(departure: departure, maxTransfers: 4))
        let parameters = Dictionary(uniqueKeysWithValues: endpoint.parameters.map { ($0.name, $0.value) })
        XCTAssertEqual(parameters["date"], "2026-11-16")
        XCTAssertEqual(parameters["time"], "22:30:00")
        XCTAssertEqual(parameters["max_transfers"], "4")
        XCTAssertEqual(parameters["ranking_priority"], "least_walking")
    }

    func testDepartNowOmitsDateAndTime() {
        let endpoint = TransitAPIEndpoint.plan(origin: .saoPaulo, destination: .saoPaulo,
            maxAlternatives: 5, rankingPriority: "arrives_first")
        XCTAssertFalse(endpoint.parameters.contains { ["date", "time"].contains($0.name) })
        XCTAssertEqual(endpoint.parameters.first { $0.name == "max_transfers" }?.value, "3")
    }

    func testExtendedGTFSTimes() {
        XCTAssertEqual(TripPlanTime.display("25:04:59"), "01:04 (+1d)")
        XCTAssertEqual(TripPlanTime.display("08:30"), "08:30")
        XCTAssertEqual(TripPlanTime.display(nil), "--:--")
    }

    func testUseCaseForwardsPreferencesThroughRepositoryToRequest() async throws {
        let fixture = Bundle.module.url(forResource: "planner-multimodal", withExtension: "json", subdirectory: "Fixtures")!
        PlannerContractURLProtocol.responseData = try Data(contentsOf: fixture)
        let departure = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-17T01:30:00Z"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PlannerContractURLProtocol.self]
        let repository = TransitAPIRepository(apiClient: APIClient(session: URLSession(configuration: configuration)))
        let plan = try await PlanTripUseCase(transitRepository: repository).execute(
            origin: .saoPaulo, destination: .saoPaulo, rankingPriority: "least_walking",
            options: TripPlanningOptions(departure: departure, maxTransfers: 2))
        XCTAssertEqual(plan.alternatives.first?.legs.count, 3)
        let url = try XCTUnwrap(PlannerContractURLProtocol.lastRequest?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let parameters = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
        XCTAssertEqual(url.path, "/api/plan.php")
        XCTAssertEqual(parameters["date"], "2026-11-16")
        XCTAssertEqual(parameters["time"], "22:30:00")
        XCTAssertEqual(parameters["max_transfers"], "2")
        XCTAssertEqual(parameters["ranking_priority"], "least_walking")
    }

    func testRailAlertsMatchOnlyTheAffectedRailLine() {
        let alert = railStatus(number: "1")
        XCTAssertTrue(alert.matches(railLeg(number: "METRÔ L1")))
        XCTAssertFalse(alert.matches(railLeg(number: "METRÔ L11")))
        XCTAssertFalse(alert.matches(railLeg(number: "CPTM L1", mode: "rail")))
        XCTAssertFalse(alert.matches(railLeg(number: "1", mode: "bus")))
        XCTAssertTrue(alert.isDisrupted)
        XCTAssertFalse(railStatus(status: "Operação Normal").isDisrupted)
        XCTAssertFalse(railStatus(status: "Status indisponível").hasKnownStatus)
        XCTAssertTrue(railStatus(status: "Em normalização").isDisrupted)
        XCTAssertTrue(railStatus(status: "Serviço indisponível").isDisrupted)
    }

    func testRailFreshnessUsesFetchTimeAndAvailability() {
        let now = Date()
        XCTAssertFalse(railStatus(fetchedAt: now).isStale(at: now))
        XCTAssertTrue(railStatus(fetchedAt: now.addingTimeInterval(-3600)).isStale(at: now))
        XCTAssertTrue(railStatus(fetchedAt: now, available: false).isStale(at: now))
        XCTAssertTrue(railStatus(fetchedAt: nil).isStale(at: now))
    }

    @MainActor
    func testStatusStoreFiltersAlertsAndReportsMissingCoverage() async throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let stamp = formatter.string(from: Date())
        let json = """
        {"metro":{"source":"metro","available":true,"count":2,"lastFetchedAt":"\(stamp)","lines":[
          {"lineNumber":"1","lineName":"Azul","status":"Velocidade Reduzida","statusDetail":"Sinalização","statusColor":"#FFFF00"},
          {"lineNumber":"2","lineName":"Verde","status":"Operação Normal","statusDetail":"","statusColor":"#00FF00"}]},
         "cptm":{"source":"cptm","available":false,"count":0,"lines":[]}}
        """
        PlannerContractURLProtocol.responseData = Data(json.utf8)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PlannerContractURLProtocol.self]
        let store = JourneyConditionsStore(apiClient: APIClient(session: URLSession(configuration: config)))
        await store.refresh()
        let affected = TripPlanAlternative(type: .transfer, legCount: 2, lineSummary: "", legs: [railLeg(number: "1"), railLeg(number: "2")])
        XCTAssertEqual(store.alerts(for: affected).map(\.lineNumber), ["1"])
        XCTAssertFalse(store.statusUnavailable(for: affected))
        let missing = TripPlanAlternative(type: .direct, legCount: 1, lineSummary: "", legs: [railLeg(number: "11", mode: "rail")])
        XCTAssertTrue(store.alerts(for: missing).isEmpty)
        XCTAssertTrue(store.statusUnavailable(for: missing))
    }

    @MainActor
    func testStatusFailureDoesNotPreventJourneyResults() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PlannerOfflineURLProtocol.self]
        let store = JourneyConditionsStore(apiClient: APIClient(session: URLSession(configuration: config)))
        await store.refresh()
        let alternative = TripPlanAlternative(type: .direct, legCount: 1, lineSummary: "", legs: [railLeg(number: "1")])
        XCTAssertTrue(store.failed)
        XCTAssertTrue(store.statusUnavailable(for: alternative))
        XCTAssertTrue(store.alerts(for: alternative).isEmpty)
    }

    func testLiveArrivalsRequireSameStopLineDirectionAndNearDeparture() {
        let now = Date(timeIntervalSince1970: 1794913200)
        var leg = railLeg(number: "715M-10", mode: "bus")
        leg.departureTimestamp = now.addingTimeInterval(300).timeIntervalSince1970
        leg.headsign = "Terminal"
        let live = arrival(live: true, direction: "Terminal")
        XCTAssertNotNil(JourneyLiveArrival.match([live], leg: leg, now: now))
        XCTAssertNil(JourneyLiveArrival.match([arrival(live: false, direction: "Terminal")], leg: leg, now: now))
        XCTAssertNil(JourneyLiveArrival.match([arrival(live: true, direction: "Outro terminal")], leg: leg, now: now))
        leg.departureTimestamp = now.addingTimeInterval(86400).timeIntervalSince1970
        XCTAssertNil(JourneyLiveArrival.match([live], leg: leg, now: now))
        let prediction = JourneyLiveArrival(expectedAt: now.addingTimeInterval(300), checkedAt: now, headsign: "Terminal")
        XCTAssertTrue(prediction.isFresh(at: now))
        XCTAssertFalse(prediction.isFresh(at: now.addingTimeInterval(100)))
    }

    @MainActor
    func testEditingASelectedPlaceInvalidatesCoordinatesAndResults() async throws {
        let planner = ControlledPlanner(plan: try decode())
        let model = SearchViewModel(planTripUseCase: planner, locationService: PlannerLocationStub())
        model.selectPlace(.saoPaulo, name: "Home", isOrigin: true)
        model.selectPlace(Location(latitude: -23.54, longitude: -46.62), name: "Work", isOrigin: false)
        XCTAssertTrue(model.canPlan)
        await model.planTrip()
        XCTAssertTrue(model.hasPlanned)
        XCTAssertEqual(model.resultContext?.destinationLabel, "Work")
        model.destinationQuery = "New destination"
        XCTAssertNil(model.destinationLocation)
        XCTAssertFalse(model.canPlan)
        XCTAssertTrue(model.alternatives.isEmpty)
        XCTAssertNil(model.resultContext)
    }

    // MARK: - Saved routes, free tier limits and the remembered form

    private let emptyPlan = TripPlan(alternatives: [], rankingPriority: "arrives_first")
    private let work = Location(latitude: -23.54, longitude: -46.62)

    @MainActor
    private func plannerModel(planner: ControlledPlanner, storage: InMemoryPlannerStore, premium: Bool = false,
                              clock: @escaping () -> Date = Date.init, location: PlannerLocationStub = PlannerLocationStub()) -> SearchViewModel {
        SearchViewModel(planTripUseCase: planner, locationService: location, storage: storage,
                        isPremium: { premium }, now: clock)
    }

    @MainActor
    func testNowSearchesSendTheTimeTheButtonIsPressed() async {
        let planner = ControlledPlanner(plan: emptyPlan)
        var clock = Date(timeIntervalSince1970: 1_794_840_000)
        let model = plannerModel(planner: planner, storage: InMemoryPlannerStore(), clock: { clock })
        model.selectPlace(.saoPaulo, name: "Home", isOrigin: true)
        model.selectPlace(work, name: "Work", isOrigin: false)
        await model.planTrip()
        clock = clock.addingTimeInterval(420)
        await model.planTrip()
        XCTAssertEqual(planner.requested, [Date(timeIntervalSince1970: 1_794_840_000), Date(timeIntervalSince1970: 1_794_840_420)])
    }

    @MainActor
    func testFreeUsersGetFiveSearchesPerDay() async {
        let planner = ControlledPlanner(plan: emptyPlan)
        let storage = InMemoryPlannerStore()
        var clock = Date(timeIntervalSince1970: 1_794_840_000)
        let model = plannerModel(planner: planner, storage: storage, clock: { clock })
        model.selectPlace(.saoPaulo, name: "Home", isOrigin: true)
        model.selectPlace(work, name: "Work", isOrigin: false)
        for _ in 0..<PlannerLimits.freeDailySearches { await model.planTrip() }
        XCTAssertEqual(model.searchesLeft, 0)
        await model.planTrip()
        XCTAssertEqual(planner.requested.count, PlannerLimits.freeDailySearches)
        XCTAssertEqual(model.premiumPrompt, .searchLimit)
        clock = clock.addingTimeInterval(86_400)
        await model.planTrip()
        XCTAssertEqual(planner.requested.count, PlannerLimits.freeDailySearches + 1)
    }

    @MainActor
    func testPremiumHasUnlimitedSearchesAndChosenTimes() async {
        let planner = ControlledPlanner(plan: emptyPlan)
        let model = plannerModel(planner: planner, storage: InMemoryPlannerStore(), premium: true)
        model.selectPlace(.saoPaulo, name: "Home", isOrigin: true)
        model.selectPlace(work, name: "Work", isOrigin: false)
        XCTAssertTrue(model.chooseDepartureTime())
        let chosen = Date(timeIntervalSince1970: 1_795_000_000)
        model.departureDate = chosen
        for _ in 0..<(PlannerLimits.freeDailySearches + 2) { await model.planTrip() }
        XCTAssertEqual(planner.requested.count, PlannerLimits.freeDailySearches + 2)
        XCTAssertTrue(planner.requested.allSatisfy { $0 == chosen })
        XCTAssertNil(model.searchesLeft)
    }

    @MainActor
    func testFreeUsersCannotChooseATime() {
        let model = plannerModel(planner: ControlledPlanner(plan: emptyPlan), storage: InMemoryPlannerStore())
        XCTAssertFalse(model.chooseDepartureTime())
        XCTAssertFalse(model.useDepartureTime)
        XCTAssertEqual(model.premiumPrompt, .chooseTime)
    }

    @MainActor
    func testFreeUsersCanSaveTwoRoutes() {
        let storage = InMemoryPlannerStore()
        let model = plannerModel(planner: ControlledPlanner(plan: emptyPlan), storage: storage)
        model.selectPlace(.saoPaulo, name: "Home", isOrigin: true)
        model.selectPlace(work, name: "Work", isOrigin: false)
        model.saveCurrentRoute()
        model.swapLocations()
        model.saveCurrentRoute()
        model.selectPlace(Location(latitude: -23.5, longitude: -46.6), name: "Gym", isOrigin: false)
        model.saveCurrentRoute()
        XCTAssertEqual(storage.routes.count, PlannerLimits.freeSavedRoutes)
        XCTAssertEqual(model.premiumPrompt, .saveLimit)
    }

    @MainActor
    func testSavedCurrentLocationRouteResolvesWhereYouAreAndSearchesNow() async {
        let planner = ControlledPlanner(plan: emptyPlan)
        let storage = InMemoryPlannerStore()
        let location = PlannerLocationStub()
        location.current = .saoPaulo
        let model = plannerModel(planner: planner, storage: storage, location: location)
        XCTAssertTrue(model.originIsCurrentLocation)
        model.selectPlace(work, name: "Work", isOrigin: false)
        model.saveCurrentRoute()
        let route = try! XCTUnwrap(storage.routes.first)
        XCTAssertTrue(route.originIsCurrentLocation)

        let moved = Location(latitude: -23.60, longitude: -46.70)
        location.current = moved
        await model.useRoute(route)
        XCTAssertEqual(model.originLocation, moved)
        XCTAssertEqual(planner.requested.count, 1)
        XCTAssertTrue(model.hasPlanned)
    }

    @MainActor
    func testLastFormIsRememberedAndClearKeepsPreferences() {
        let storage = InMemoryPlannerStore()
        let first = plannerModel(planner: ControlledPlanner(plan: emptyPlan), storage: storage)
        first.selectPlace(.saoPaulo, name: "Home", isOrigin: true)
        first.selectPlace(work, name: "Work", isOrigin: false)
        first.rankingPriority = "least_walking"

        let reopened = plannerModel(planner: ControlledPlanner(plan: emptyPlan), storage: storage)
        XCTAssertEqual(reopened.originQuery, "Home")
        XCTAssertEqual(reopened.destinationLocation, work)
        XCTAssertEqual(reopened.rankingPriority, "least_walking")
        XCTAssertTrue(reopened.canPlan)

        reopened.clearField(isOrigin: false)
        XCTAssertNil(reopened.destinationLocation)
        XCTAssertNotNil(reopened.originLocation)
        reopened.clearForm()
        XCTAssertEqual(reopened.originQuery, "")
        XCTAssertFalse(reopened.hasFormContent)
        XCTAssertEqual(reopened.rankingPriority, "least_walking")
        XCTAssertNil(storage.form?.destination)
    }

    // MARK: - Shared journeys

    func testShareLinksAreRecognisedStrictly() {
        XCTAssertEqual(JourneyShareLink.token(from: URL(string: "https://sptrans.lolados.app/j/Hv8EVpDjMTV2")!), "Hv8EVpDjMTV2")
        XCTAssertNil(JourneyShareLink.token(from: URL(string: "https://sptrans.lolados.app/j/short")!))
        XCTAssertNil(JourneyShareLink.token(from: URL(string: "https://evil.example/j/Hv8EVpDjMTV2")!))
        XCTAssertNil(JourneyShareLink.token(from: URL(string: "https://sptrans.lolados.app/api/share.php?t=Hv8EVpDjMTV2")!))
        XCTAssertNil(JourneyShareLink.token(from: URL(string: "duesp://stop?stop_id=1")!))
    }

    func testShareRequestSendsReferencesOnly() throws {
        let alternative = try decode().alternatives[0]
        // 23:50 on 16 Nov in São Paulo is already 17 Nov in UTC: the service day must stay the 16th.
        let departure = ISO8601DateFormatter().date(from: "2026-11-17T02:50:00Z")!
        let request = try XCTUnwrap(JourneyShareService.request(for: alternative, departureDate: departure))
        XCTAssertEqual(request.date, "2026-11-16")
        XCTAssertEqual(request.legs.count, alternative.vehicleLegs.count)
        XCTAssertEqual(request.legs.first?.tripId, alternative.vehicleLegs.first?.tripId)
        XCTAssertEqual(request.legs.first?.departure, alternative.vehicleLegs.first?.departureTime)
        let body = String(data: try JSONEncoder().encode(request), encoding: .utf8)!
        XCTAssertFalse(body.contains("lat"), "origin/destination must never be sent")
    }

    func testWalkOnlyJourneysCannotBeShared() throws {
        let walk = try XCTUnwrap(try decode().walkingAlternative)
        XCTAssertNil(JourneyShareService.request(for: walk, departureDate: Date()))
    }

    func testYellowLineGetsDarkBadgeTextAndDarkerTextOnWhite() throws {
        // The API sends white text for Metrô L4 (FFD700).
        XCTAssertEqual(LineColor.badgeText(background: "FFD700", preferred: "FFFFFF"), LineColor.darkText)
        let readable = try XCTUnwrap(LineColor.readable("FFD700", on: LineColor.lightSurface, minimumContrast: LineColor.textContrast))
        XCTAssertGreaterThanOrEqual(LineColor.contrast(LineColor.parse(readable)!, LineColor.parse("FFFFFF")!), LineColor.textContrast)
    }

    func testReadableLineColorsAreKept() throws {
        // Navy bus with white text: both already readable.
        XCTAssertEqual(LineColor.badgeText(background: "002F6C", preferred: "FFFFFF"), "FFFFFF")
        XCTAssertEqual(LineColor.readable("002F6C", on: LineColor.lightSurface, minimumContrast: LineColor.textContrast), "002F6C")
        // On a dark card the navy is lightened instead.
        let onDark = try XCTUnwrap(LineColor.readable("002F6C", on: LineColor.darkSurface, minimumContrast: LineColor.graphicContrast))
        XCTAssertGreaterThanOrEqual(LineColor.contrast(LineColor.parse(onDark)!, LineColor.parse(LineColor.darkSurface)!), LineColor.graphicContrast)
        // Missing or invalid colours fall back to the caller's default.
        XCTAssertNil(LineColor.readable("", on: LineColor.lightSurface, minimumContrast: 3))
        XCTAssertEqual(LineColor.badgeText(background: nil, preferred: nil), LineColor.lightText)
    }

    @MainActor
    func testTextFieldRewritingTheSameTextKeepsTheSelectedPlace() {
        let model = SearchViewModel(planTripUseCase: ControlledPlanner(plan: TripPlan(alternatives: [], rankingPriority: "arrives_first")), locationService: PlannerLocationStub())
        model.selectPlace(.saoPaulo, name: "Home", isOrigin: true)
        model.selectPlace(Location(latitude: -23.54, longitude: -46.62), name: "Estação da Luz", isOrigin: false)
        // SwiftUI writes the unchanged text back when the field loses focus.
        model.destinationQuery = "Estação da Luz"
        model.originQuery = "Home"
        XCTAssertNotNil(model.destinationLocation)
        XCTAssertNotNil(model.originLocation)
        XCTAssertTrue(model.canPlan)
    }

    @MainActor
    func testOriginFillsWithCurrentLocationOnceAvailable() {
        let location = PlannerLocationStub()
        let model = SearchViewModel(planTripUseCase: ControlledPlanner(plan: TripPlan(alternatives: [], rankingPriority: "arrives_first")), locationService: location)
        XCTAssertNil(model.originLocation)
        location.current = .saoPaulo
        model.fillOriginWithCurrentLocationIfEmpty()
        XCTAssertEqual(model.originLocation, .saoPaulo)
        // A place the user typed or chose is never replaced.
        model.selectPlace(Location(latitude: -23.54, longitude: -46.62), name: "Work", isOrigin: true)
        model.fillOriginWithCurrentLocationIfEmpty()
        XCTAssertEqual(model.originQuery, "Work")
    }

    @MainActor
    func testSwapExchangesBothNamesAndCoordinates() async {
        let model = SearchViewModel(planTripUseCase: ControlledPlanner(plan: TripPlan(alternatives: [], rankingPriority: "arrives_first")), locationService: PlannerLocationStub())
        let destination = Location(latitude: -23.54, longitude: -46.62)
        model.selectPlace(.saoPaulo, name: "Home", isOrigin: true)
        model.selectPlace(destination, name: "Work", isOrigin: false)
        model.swapLocations()
        XCTAssertEqual(model.originQuery, "Work")
        XCTAssertEqual(model.originLocation, destination)
        XCTAssertEqual(model.destinationQuery, "Home")
        XCTAssertEqual(model.destinationLocation, .saoPaulo)
        XCTAssertTrue(model.canPlan)
    }

    @MainActor
    func testInFlightResponseCannotOverwriteEditedLocations() async throws {
        let planner = ControlledPlanner(plan: try decode())
        planner.shouldSuspend = true
        let model = SearchViewModel(planTripUseCase: planner, locationService: PlannerLocationStub())
        model.selectPlace(.saoPaulo, name: "Home", isOrigin: true)
        model.selectPlace(.saoPaulo, name: "Work", isOrigin: false)
        let task = Task { await model.planTrip() }
        while planner.continuation == nil { await Task.yield() }
        model.originQuery = "Different place"
        planner.continuation?.resume()
        await task.value
        XCTAssertFalse(model.hasPlanned)
        XCTAssertFalse(model.isPlanning)
        XCTAssertTrue(model.alternatives.isEmpty)
    }

    private func railLeg(number: String, mode: String = "metro") -> TripPlanLeg {
        TripPlanLeg(route: TripPlanRoute(routeId: number, shortName: number, longName: "Line", color: "007AFF", textColor: "FFFFFF"),
            tripId: "test", originStopId: 1, destinationStopId: 2, originStop: nil, destinationStop: nil, mode: mode)
    }

    private func railStatus(number: String = "1", status: String = "Velocidade Reduzida", fetchedAt: Date? = Date(), available: Bool = true) -> JourneyRailLineStatus {
        JourneyRailLineStatus(source: "metro", lineNumber: number, lineName: "Azul", status: status, detail: "Signal failure",
            updatedAt: nil, fetchedAt: fetchedAt, available: available)
    }

    private func arrival(live: Bool, direction: String) -> Arrival {
        Arrival(tripId: "ov-test", routeId: "99999", routeShortName: "715M-10", routeLongName: "Line", headsign: direction,
            arrivalTime: "10:05", departureTime: "10:05", stopId: 1, stopSequence: 0, routeType: 3,
            routeColor: "", routeTextColor: "", frequency: nil, waitTime: 5, isLiveFromOlhoVivo: live)
    }

    @MainActor
    private func detail(_ alternative: TripPlanAlternative) -> TripPlanDetailViewModel {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PlannerOfflineURLProtocol.self]
        let repository = TransitAPIRepository(apiClient: APIClient(session: URLSession(configuration: configuration)))
        return TripPlanDetailViewModel(alternative: alternative,
            originLocation: Location(latitude: -23.55, longitude: -46.63),
            destinationLocation: Location(latitude: -23.54, longitude: -46.63),
            originLabel: "Home", destinationLabel: "Work",
            getTripRouteUseCase: GetTripRouteUseCase(transitRepository: repository),
            getRouteShapeUseCase: GetRouteShapeUseCase(transitRepository: repository))
    }
}

private final class PlannerOfflineURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}

private final class PlannerContractURLProtocol: URLProtocol {
    static var responseData = Data()
    static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class PlannerLocationStub: LocationServiceProtocol {
    var current: Location?
    func requestLocationPermission() {}
    func getCurrentLocation() -> Location? { current }
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}
}

private final class ControlledPlanner: PlanTripUseCase {
    let plan: TripPlan
    var shouldSuspend = false
    var continuation: CheckedContinuation<Void, Never>?
    var requested: [Date?] = []
    init(plan: TripPlan) {
        self.plan = plan
        super.init(transitRepository: TransitAPIRepository(apiClient: APIClient()))
    }
    override func execute(origin: Location, destination: Location, maxAlternatives: Int = 5,
        rankingPriority: String = "arrives_first", options: TripPlanningOptions = TripPlanningOptions()) async throws -> TripPlan {
        requested.append(options.departure)
        if shouldSuspend { await withCheckedContinuation { continuation = $0 } }
        return plan
    }
}
