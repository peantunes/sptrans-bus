import Foundation

enum AppDeepLink {
    case status(lineID: String?)
    case stopDetail(Stop)
}

enum AppDeepLinkBuilder {
    static let scheme = "duesp"

    static func status(lineID: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "status"
        if let lineID, !lineID.isEmpty {
            components.queryItems = [URLQueryItem(name: "line_id", value: lineID)]
        }
        return components.url
    }

    static func stopDetail(stop: Stop) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "stop"
        components.queryItems = [
            URLQueryItem(name: "stop_id", value: "\(stop.stopId)"),
            URLQueryItem(name: "name", value: stop.stopName),
            URLQueryItem(name: "lat", value: "\(stop.location.latitude)"),
            URLQueryItem(name: "lon", value: "\(stop.location.longitude)"),
            URLQueryItem(name: "code", value: stop.stopCode),
            URLQueryItem(name: "routes", value: stop.routes ?? "")
        ]
        return components.url
    }

    static func stopDetail(stop: WatchStopSnapshot) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "stop"
        components.queryItems = [
            URLQueryItem(name: "stop_id", value: "\(stop.stopId)"),
            URLQueryItem(name: "name", value: stop.stopName),
            URLQueryItem(name: "lat", value: "\(stop.latitude)"),
            URLQueryItem(name: "lon", value: "\(stop.longitude)"),
            URLQueryItem(name: "code", value: stop.stopCode),
            URLQueryItem(name: "routes", value: stop.routes ?? "")
        ]
        return components.url
    }
}

enum AppDeepLinkParser {
    static func parse(url: URL) -> AppDeepLink? {
        guard url.scheme?.lowercased() == AppDeepLinkBuilder.scheme else {
            return nil
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let route: String = {
            let host = (components.host ?? "").lowercased()
            let segments = components.path
                .split(separator: "/")
                .map { $0.lowercased() }
            if host == "open" {
                return segments.first ?? ""
            }
            if !host.isEmpty {
                return host
            }
            return segments.first ?? ""
        }()

        switch route {
        case "status":
            return .status(lineID: components.queryItem(named: "line_id"))
        case "stop":
            return parseStopDetail(from: components)
        default:
            return nil
        }
    }

    private static func parseStopDetail(from components: URLComponents) -> AppDeepLink? {
        guard let rawStopID = components.queryItem(named: "stop_id"),
              let stopID = Int(rawStopID) else {
            return nil
        }

        let name = components.queryItem(named: "name") ?? "Parada \(stopID)"
        let latitude = Double(components.queryItem(named: "lat") ?? "") ?? Location.saoPaulo.latitude
        let longitude = Double(components.queryItem(named: "lon") ?? "") ?? Location.saoPaulo.longitude
        let stopCode = components.queryItem(named: "code") ?? ""
        let routes = components.queryItem(named: "routes")

        let stop = Stop(
            stopId: stopID,
            stopName: name,
            location: Location(latitude: latitude, longitude: longitude),
            stopSequence: 0,
            routes: routes,
            stopCode: stopCode,
            wheelchairBoarding: 0
        )
        return .stopDetail(stop)
    }
}

private extension URLComponents {
    func queryItem(named name: String) -> String? {
        queryItems?.first(where: { $0.name == name })?.value
    }
}
