import AppIntents
import Foundation

struct GetNextArrivalsIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.arrivals.title"
    static var description = IntentDescription("intent.arrivals.description")

    @Parameter(title: "intent.arrivals.parameter.stop")
    var stop: StopEntity

    @Parameter(
        title: "intent.arrivals.parameter.limit",
        requestValueDialog: IntentDialog("intent.arrivals.parameter.limit_dialog")
    )
    var limit: Int

    static var parameterSummary: some ParameterSummary {
        Summary("intent.arrivals.summary")
    }

    init() {
        limit = 5
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let clampedLimit = min(max(limit, 1), 20)
        let arrivals = try await AppIntentTransitService.getArrivals(stopId: stop.id, limit: clampedLimit)

        guard !arrivals.isEmpty else {
            let emptyMessage = AppIntentL10n.format("intent.arrivals.empty", stop.stopName)
            return .result(value: emptyMessage, dialog: IntentDialog(stringLiteral: emptyMessage))
        }

        let preview = arrivals.prefix(3).map { arrival in
            AppIntentL10n.format("intent.arrivals.preview_item_format", arrival.routeShortName, arrival.formattedWaitTime)
        }.joined(separator: ", ")

        let message = AppIntentL10n.format("intent.arrivals.result_format", arrivals.count, stop.stopName, preview)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
