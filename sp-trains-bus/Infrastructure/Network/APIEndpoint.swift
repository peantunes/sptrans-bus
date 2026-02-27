import Foundation

protocol APIEndpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: String { get }
    var headers: [String: String]? { get }
    var parameters: [URLQueryItem] { get }
    var body: Data? { get }
}

extension APIEndpoint {
    var baseURL: URL {
        return URL(string: "https://sptrans.lolados.app/api")!
    }

    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }

    var body: Data? {
        return nil
    }
}

enum TransitAPIEndpoint {
    case nearby(lat: Double, lon: Double, limit: Int)
    case arrivals(stopId: Int, limit: Int)
    case arrivalsPaged(
        stopId: Int,
        limit: Int,
        date: String?,
        time: String?,
        cursorDate: String?,
        cursorTime: String?,
        direction: ArrivalsPageDirection
    )
    case search(query: String)
    case trip(tripId: String)
    case shape(shapeId: String)
    case stop(stopId: Int)
    case routes
    case metroCPTM(refresh: Bool)
    case railStatusReport(periodDays: Int)
    case railAlertSubscriptionsState(installationId: String)
    case railAlertSubscriptionsUpdate(payload: RailAlertSubscriptionUpdateRequestDTO)
    case plan(origin: Location, destination: Location, maxAlternatives: Int, rankingPriority: String)
}

extension TransitAPIEndpoint: APIEndpoint {
    var path: String {
        switch self {
        case .nearby:
            return "/nearby.php"
        case .arrivals:
            return "/arrivals.php"
        case .arrivalsPaged:
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
        case .metroCPTM:
            return "/metro_cptm.php"
        case .railStatusReport:
            return "/rail_status_report.php"
        case .railAlertSubscriptionsState, .railAlertSubscriptionsUpdate:
            return "/rail_alert_subscriptions.php"
        case .plan:
            return "/plan.php"
        }
    }

    var method: String {
        switch self {
        case .railAlertSubscriptionsUpdate:
            return "POST"
        default:
            return "GET"
        }
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
                URLQueryItem(name: "stop_id", value: "\(stopId)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        case .arrivalsPaged(let stopId, let limit, let date, let time, let cursorDate, let cursorTime, let direction):
            var items = [
                URLQueryItem(name: "stop_id", value: "\(stopId)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "direction", value: direction.rawValue)
            ]
            if let date {
                items.append(URLQueryItem(name: "date", value: date))
            }
            if let time {
                items.append(URLQueryItem(name: "time", value: time))
            }
            if let cursorDate {
                items.append(URLQueryItem(name: "cursor_date", value: cursorDate))
            }
            if let cursorTime {
                items.append(URLQueryItem(name: "cursor_time", value: cursorTime))
            }
            return items
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
                URLQueryItem(name: "stop_id", value: "\(stopId)")
            ]
        case .routes:
            return []
        case .metroCPTM(let refresh):
            return refresh ? [URLQueryItem(name: "refresh", value: "1")] : []
        case .railStatusReport(let periodDays):
            return [
                URLQueryItem(name: "period_days", value: "\(periodDays)")
            ]
        case .railAlertSubscriptionsState(let installationId):
            return [
                URLQueryItem(name: "installation_id", value: installationId)
            ]
        case .railAlertSubscriptionsUpdate:
            return []
        case .plan(let origin, let destination, let maxAlternatives, let rankingPriority):
            return [
                URLQueryItem(name: "origin_lat", value: "\(origin.latitude)"),
                URLQueryItem(name: "origin_lon", value: "\(origin.longitude)"),
                URLQueryItem(name: "dest_lat", value: "\(destination.latitude)"),
                URLQueryItem(name: "dest_lon", value: "\(destination.longitude)"),
                URLQueryItem(name: "max_alternatives", value: "\(maxAlternatives)"),
                URLQueryItem(name: "ranking_priority", value: rankingPriority)
            ]
        }
    }

    var body: Data? {
        switch self {
        case .railAlertSubscriptionsUpdate(let payload):
            return try? JSONEncoder().encode(payload)
        default:
            return nil
        }
    }
}
