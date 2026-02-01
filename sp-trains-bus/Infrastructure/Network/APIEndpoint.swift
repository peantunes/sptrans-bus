import Foundation

protocol APIEndpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: String { get }
    var headers: [String: String]? { get }
    var parameters: [URLQueryItem] { get }
}

extension APIEndpoint {
    var baseURL: URL {
        return URL(string: "http://192.168.1.49:8080/api")!
    }

    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }
}

enum TransitAPIEndpoint {
    case nearby(lat: Double, lon: Double, limit: Int)
    case arrivals(stopId: String, limit: Int)
    case search(query: String)
    case trip(tripId: String)
    case shape(shapeId: String)
    case stop(stopId: String)
    case routes
}

extension TransitAPIEndpoint: APIEndpoint {
    var path: String {
        switch self {
        case .nearby:
            return "/nearby.php"
        case .arrivals:
            return "/arrivals.php"
        case .search:
            return "/search.php"
        case .trip:
            return "/trip.php"
        case .shape:
            return "/shape.php"
        case .stop:
            return "/stop.php"
        case .routes:
            return "/routes.php"
        }
    }

    var method: String {
        return "GET"
    }

    var parameters: [URLQueryItem] {
        switch self {
        case .nearby(let lat, let lon, let limit):
            return [
                URLQueryItem(name: "lat", value: "\(lat)"),
                URLQueryItem(name: "lon", value: "\(lon)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        case .arrivals(let stopId, let limit):
            return [
                URLQueryItem(name: "stop_id", value: stopId),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        case .search(let query):
            return [
                URLQueryItem(name: "q", value: query)
            ]
        case .trip(let tripId):
            return [
                URLQueryItem(name: "trip_id", value: tripId)
            ]
        case .shape(let shapeId):
            return [
                URLQueryItem(name: "shape_id", value: shapeId)
            ]
        case .stop(let stopId):
            return [
                URLQueryItem(name: "stop_id", value: stopId)
            ]
        case .routes:
            return []
        }
    }
}
