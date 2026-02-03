import XCTest
@testable import sp_trains_bus

class DomainLayerTests: XCTestCase {

    func testLocationInitialization() {
        let location = Location(latitude: 34.0522, longitude: -118.2437)
        XCTAssertEqual(location.latitude, 34.0522)
        XCTAssertEqual(location.longitude, -118.2437)
    }

    func testStopInitialization() {
        let location = Location(latitude: 34.0522, longitude: -118.2437)
        let stop = Stop(stopId: 1, stopName: "Test Stop", location: location, stopSequence: 5, stopCode: "TS1", wheelchairBoarding: 0)
        XCTAssertEqual(stop.stopId, 1)
        XCTAssertEqual(stop.stopName, "Test Stop")
        XCTAssertEqual(stop.location.latitude, 34.0522)
    }

    func testArrivalInitialization() {
        let arrival = Arrival(tripId: "T1", routeId: "R1", routeShortName: "R1", routeLongName: "Route 1", headsign: "Downtown", arrivalTime: "10:00", departureTime: "10:01", stopId: 1, stopSequence: 1, routeType: 3, routeColor: "FF0000", routeTextColor: "FFFFFF", frequency: 10, waitTime: 5)
        XCTAssertEqual(arrival.tripId, "T1")
        XCTAssertEqual(arrival.arrivalTime, "10:00")
        XCTAssertEqual(arrival.waitTime, 5)
    }

    func testRouteInitialization() {
        let route = Route(routeId: "R1", agencyId: 1, routeShortName: "10", routeLongName: "Main Street", routeDesc: "Bus Route", routeType: 3, routeColor: "FFFFFF", routeTextColor: "000000")
        XCTAssertEqual(route.routeId, "R1")
        XCTAssertEqual(route.routeShortName, "10")
    }

    func testTripInitialization() {
        let trip = Trip(routeId: "R1", serviceId: "S1", tripId: "T1", tripHeadsign: "Downtown", directionId: 0, shapeId: "SH1")
        XCTAssertEqual(trip.tripId, "T1")
        XCTAssertEqual(trip.shapeId, "SH1")
    }

    func testMetroLineInitialization() {
        let metroLine = MetroLine(line: "L1", name: "Red Line", colorHex: "FF0000")
        XCTAssertEqual(metroLine.line, "L1")
        XCTAssertEqual(metroLine.name, "Red Line")
    }
}
