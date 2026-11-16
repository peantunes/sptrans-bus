import Foundation
#if os(iOS) && canImport(ActivityKit)
import ActivityKit

/// Live Activity of a journey being tracked (app: JourneyTracker, widget: JourneyLiveActivity).
/// Shared by the app and the widget extension.
struct JourneyActivityAttributes: ActivityAttributes {
    enum Phase: String, Codable, Hashable {
        case walking
        case waiting
        case riding
        case arrived
    }

    /// Another line leaving from where you are to the same destination.
    struct Alternative: Codable, Hashable {
        let lineName: String
        let lineColorHex: String
        let lineTextHex: String
        let minutes: Int
    }

    struct ContentState: Codable, Hashable {
        var phase: Phase
        /// What to do now: "Caminhe até Av. Paulista, 1754", "Desça em Luz".
        var title: String
        /// Detail: "Embarque no 917H-10 às 08:33", "Próxima: República · 3 paradas".
        var subtitle: String
        var lineName: String?
        var lineColorHex: String?
        var lineTextHex: String?
        var modeSymbol: String
        /// The next event (departure, alighting, arrival) for the countdown.
        var nextEventDate: Date
        var arrivalDate: Date
        var stepIndex: Int
        var stepCount: Int
        var stopsLeft: Int?
        var alternatives: [Alternative]
        /// True when the position comes from GPS rather than the timetable.
        var usesLocation: Bool
    }

    let from: String
    let to: String
}
#endif
