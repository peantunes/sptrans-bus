import Foundation

enum WidgetDeepLink {
    private static let scheme = "duesp"

    static func status(lineID: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "status"
        if let lineID, !lineID.isEmpty {
            components.queryItems = [URLQueryItem(name: "line_id", value: lineID)]
        }
        return components.url
    }

    static func stopDetail(stop: WidgetStopSnapshot) -> URL? {
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
