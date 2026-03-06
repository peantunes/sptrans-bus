import AppIntents
import Foundation

struct OpenStopIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.open_stop.title"
    static var description = IntentDescription("intent.open_stop.description")

    @Parameter(title: "intent.open_stop.parameter.stop")
    var stop: StopEntity

    static var parameterSummary: some ParameterSummary {
        Summary("intent.open_stop.summary")
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        var components = URLComponents()
        components.scheme = "duesp"
        components.host = "stop"
        components.queryItems = [
            URLQueryItem(name: "stop_id", value: "\(stop.id)"),
            URLQueryItem(name: "name", value: stop.stopName),
            URLQueryItem(name: "lat", value: "\(stop.latitude)"),
            URLQueryItem(name: "lon", value: "\(stop.longitude)"),
            URLQueryItem(name: "code", value: stop.stopCode),
            URLQueryItem(name: "routes", value: stop.routes ?? "")
        ]

        guard let url = components.url else {
            return .result(opensIntent: OpenURLIntent(URL(string: "duesp://status")!))
        }

        return .result(opensIntent: OpenURLIntent(url))
    }
}
