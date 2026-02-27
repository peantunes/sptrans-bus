import XCTest
@testable import sp_trains_bus

final class OlhoVivoTransitRepositoryDecoratorTests: XCTestCase {
    private final class SpyBaseRepository: TransitRepositoryProtocol {
        var basicArrivalsCalls = 0
        var pagedArrivalsCalls = 0
        var lastPagedArguments: (
            stopId: Int,
            limit: Int,
            date: String?,
            time: String?,
            cursorDate: String?,
            cursorTime: String?,
            direction: ArrivalsPageDirection
        )?

        func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] { [] }

        func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] {
            basicArrivalsCalls += 1
            return []
        }

        func getArrivals(
            stopId: Int,
            limit: Int,
            date: String?,
            time: String?,
            cursorDate: String?,
            cursorTime: String?,
            direction: ArrivalsPageDirection
        ) async throws -> [Arrival] {
            pagedArrivalsCalls += 1
            lastPagedArguments = (stopId, limit, date, time, cursorDate, cursorTime, direction)
            return []
        }

        func searchStops(query: String, limit: Int) async throws -> [Stop] { [] }
        func getTrip(tripId: String) async throws -> TripStop { TripStop(trip: Trip(routeId: "", serviceId: "", tripId: "", tripHeadsign: "", directionId: 0, shapeId: ""), stops: []) }
        func getRoute(routeId: String) async throws -> Route {
            Route(
                routeId: "",
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

    func testPagedArrivalsForwardDateAndTimeParametersToBaseRepository() async throws {
        let spy = SpyBaseRepository()
        let sut = OlhoVivoTransitRepositoryDecorator(baseRepository: spy, olhoVivoService: nil)

        _ = try await sut.getArrivals(
            stopId: 700017107,
            limit: 20,
            date: "2026-02-27",
            time: "18:45:00",
            cursorDate: "2026-02-27",
            cursorTime: "19:15:01",
            direction: .next
        )

        XCTAssertEqual(spy.basicArrivalsCalls, 0)
        XCTAssertEqual(spy.pagedArrivalsCalls, 1)
        XCTAssertEqual(spy.lastPagedArguments?.stopId, 700017107)
        XCTAssertEqual(spy.lastPagedArguments?.limit, 20)
        XCTAssertEqual(spy.lastPagedArguments?.date, "2026-02-27")
        XCTAssertEqual(spy.lastPagedArguments?.time, "18:45:00")
        XCTAssertEqual(spy.lastPagedArguments?.cursorDate, "2026-02-27")
        XCTAssertEqual(spy.lastPagedArguments?.cursorTime, "19:15:01")
        XCTAssertEqual(spy.lastPagedArguments?.direction, .next)
    }
}
