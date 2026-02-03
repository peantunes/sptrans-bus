import XCTest
@testable import sp_trains_bus // Assuming the main module name

class NetworkLayerTests: XCTestCase {

    var apiClient: APIClient! 
    var transitRepository: TransitAPIRepository!
    var mockSession: MockURLSession!

    override func setUpWithError() throws {
        mockSession = MockURLSession()
        apiClient = APIClient(session: mockSession)
        transitRepository = TransitAPIRepository(apiClient: apiClient)
    }

    override func tearDownWithError() throws {
        apiClient = nil
        transitRepository = nil
        mockSession = nil
    }

    func testAPIClientSuccess() async throws {
        let expectedData = "{\"test\":\"data\"}".data(using: .utf8)!
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8080/api/test.php")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockSession.data = expectedData
        mockSession.response = response

        struct TestDTO: Decodable { let test: String }
        let endpoint = MockAPIEndpoint()
        let result: TestDTO = try await apiClient.request(endpoint: endpoint)

        XCTAssertEqual(result.test, "data")
    }

    func testAPIClientInvalidResponse() async throws {
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8080/api/test.php")!, statusCode: 404, httpVersion: nil, headerFields: nil)!
        mockSession.data = Data()
        mockSession.response = response

        let endpoint = MockAPIEndpoint()
        do {
            let _: String = try await apiClient.request(endpoint: endpoint)
            XCTFail("Expected invalidResponse error but got success")
        } catch let error as APIError {
            XCTAssertEqual(error, APIError.invalidResponse)
        } catch {
            XCTFail("Expected APIError.invalidResponse but got \(error)")
        }
    }

    func testGetNearbyStopsSuccess() async throws {
        let json = """
        {
          \"lat\": -23.554022,
          \"lon\": -46.671108,
          \"count\": 1,
          \"stops\": [
            {
              \"id\": \"18848\",
              \"name\": \"Clínicas\",
              \"desc\": \"\",
              \"lat\": -23.554022,
              \"lon\": -46.671108,
              \"routes\": \"1012-10, 1012-21\",
              \"distance\": 0.00001
            }
          ]
        }
        """
        let expectedData = json.data(using: .utf8)!
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8080/api/nearby.php")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockSession.data = expectedData
        mockSession.response = response

        let location = Location(latitude: -23.0, longitude: -46.0)
        let stops = try await transitRepository.getNearbyStops(location: location, limit: 1)

        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops.first?.stopName, "Clínicas")
    }

    func testGetArrivalsSuccess() async throws {
        let json = """
        {
          \"stopId\": \"18848\",
          \"queryTime\": \"14:30:00\",
          \"queryDate\": \"2024-02-01\",
          \"count\": 1,
          \"arrivals\": [
            {
              \"tripId\": \"1012-10-0\",
              \"routeId\": \"1012-10\",
              \"routeShortName\": \"1012-10\",
              \"routeLongName\": \"Term. Jd. Britania - Jd. Monte Belo\",
              \"headsign\": \"Jd. Monte Belo\",
              \"arrivalTime\": \"14:35:00\",
              \"departureTime\": \"14:35:00\",
              \"stopSequence\": 5,
              \"routeType\": 3,
              \"routeColor\": \"509E2F\",
              \"routeTextColor\": \"FFFFFF\",
              \"frequency\": 20,
              \"waitTime\": 5
            }
          ]
        }
        """
        let expectedData = json.data(using: .utf8)!
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8080/api/arrivals.php")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockSession.data = expectedData
        mockSession.response = response

        let arrivals = try await transitRepository.getArrivals(stopId: 18848, limit: 1)

        XCTAssertEqual(arrivals.count, 1)
        XCTAssertEqual(arrivals.first?.tripId, "1012-10-0")
    }

    func testSearchStopsSuccess() async throws {
        let json = """
        {
          \"query\": \"Paulista\",
          \"count\": 1,
          \"stops\": [
            {
              \"stopId\": \"12345\",
              \"stopName\": \"Av. Paulista, 1000\",
              \"stopDesc\": \"\",
              \"stopLat\": -23.561414,
              \"stopLon\": -46.656166,
              \"routes\": \"1012-10, 2345-21\"
            }
          ]
        }
        """
        let expectedData = json.data(using: .utf8)!
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8080/api/search.php")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockSession.data = expectedData
        mockSession.response = response

        let stops = try await transitRepository.searchStops(query: "Paulista", limit: 1)

        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops.first?.stopName, "Av. Paulista, 1000")
    }

    func testGetTripSuccess() async throws {
        let json = """
        {
          \"trip\": {
            \"tripId\": \"1012-10-0\",
            \"routeId\": \"1012-10\",
            \"serviceId\": \"USD\",
            \"headsign\": \"Jd. Monte Belo\",
            \"directionId\": 0,
            \"shapeId\": \"84609\",
            \"stops\": [
              {
                \"stopId\": \"301790\",
                \"stopName\": \"Term. Jd. Britania\",
                \"stopDesc\": \"\",
                \"stopLat\": -23.432024,
                \"stopLon\": -46.787121,
                \"arrivalTime\": \"07:00:00\",
                \"departureTime\": \"07:00:00\",
                \"stopSequence\": 1
              }
            ]
          }
        }
        """
        let expectedData = json.data(using: .utf8)!
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8080/api/trip.php")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockSession.data = expectedData
        mockSession.response = response

        let trip = try await transitRepository.getTrip(tripId: "1012-10-0")

        XCTAssertEqual(trip.trip.tripId, "1012-10-0")
        XCTAssertEqual(trip.trip.routeId, "1012-10")
    }

    func testGetRouteSuccess() async throws {
        let json = """
        {
          \"route\": {
            \"routeId\": \"1012-10\",
            \"agencyId\": \"1\",
            \"routeShortName\": \"1012-10\",
            \"routeLongName\": \"Term. Jd. Britania - Jd. Monte Belo\",
            \"routeType\": 3,
            \"routeColor\": \"509E2F\",
            \"routeTextColor\": \"FFFFFF\",
            \"trips\": []
          }
        }
        """
        let expectedData = json.data(using: .utf8)!
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8080/api/route.php")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockSession.data = expectedData
        mockSession.response = response

        let route = try await transitRepository.getRoute(routeId: "1012-10")

        XCTAssertEqual(route.routeId, "1012-10")
        XCTAssertEqual(route.routeShortName, "1012-10")
    }

    func testGetShapeSuccess() async throws {
        let json = """
        {
          \"shapeId\": \"84609\",
          \"count\": 2,
          \"points\": [
            {
              \"lat\": -23.432024,
              \"lon\": -46.787121,
              \"sequence\": 1,
              \"distTraveled\": 0
            },
            {
              \"lat\": -23.432100,
              \"lon\": -46.787200,
              \"sequence\": 2,
              \"distTraveled\": 15.5
            }
          ]
        }
        """
        let expectedData = json.data(using: .utf8)!
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8080/api/shape.php")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockSession.data = expectedData
        mockSession.response = response

        let shape = try await transitRepository.getShape(shapeId: "84609")

        XCTAssertEqual(shape.count, 2)
        XCTAssertEqual(shape.first?.latitude, -23.432024)
    }

    func testGetAllRoutesSuccess() async throws {
        let json = """
        {
          \"limit\": 50,
          \"offset\": 0,
          \"count\": 1,
          \"routes\": [
            {
              \"routeId\": \"1012-10\",
              \"routeShortName\": \"1012-10\",
              \"routeLongName\": \"Term. Jd. Britania - Jd. Monte Belo\",
              \"routeType\": 3,
              \"routeColor\": \"509E2F\",
              \"routeTextColor\": \"FFFFFF\"
            }
          ]
        }
        """
        let expectedData = json.data(using: .utf8)!
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8080/api/routes.php")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockSession.data = expectedData
        mockSession.response = response

        let routes = try await transitRepository.getAllRoutes(limit: 1, offset: 0)

        XCTAssertEqual(routes.count, 1)
        XCTAssertEqual(routes.first?.routeId, "1012-10")
    }

    // MARK: - Mocks

    class MockURLSession: URLSession {
        var data: Data?
        var response: URLResponse?
        var error: Error?

        override func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
            if let error = error {
                throw error
            }
            if let data = data, let response = response {
                return (data, response)
            }
            fatalError("MockURLSession not configured with data or response")
        }
    }

    struct MockAPIEndpoint: APIEndpoint {
        var baseURL: URL { URL(string: "http://localhost:8080/api")! }
        var path: String { "/test.php" }
        var method: String { "GET" }
        var headers: [String : String]? { nil }
        var parameters: [URLQueryItem] { [] }
    }
}
