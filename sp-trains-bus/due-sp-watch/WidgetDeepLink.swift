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
}
