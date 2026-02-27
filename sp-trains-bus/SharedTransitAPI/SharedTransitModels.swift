import Foundation

struct SharedTransitSnapshot {
    var generatedAt: Date
    var railLines: [SharedRailLine]
    var nearbyStops: [SharedStop]
    var arrivalsByStopID: [String: [SharedArrival]]

    static let empty = SharedTransitSnapshot(
        generatedAt: .distantPast,
        railLines: [],
        nearbyStops: [],
        arrivalsByStopID: [:]
    )
}

struct SharedRailLine: Identifiable {
    let id: String
    let source: String
    let lineNumber: String
    let lineName: String
    let status: String
    let detail: String
    let statusColorHex: String
    let lineColorHex: String
    let severityRawValue: Int
    let isFavorite: Bool
}

struct SharedStop: Identifiable {
    var id: Int { stopId }
    let stopId: Int
    let stopName: String
    let latitude: Double
    let longitude: Double
    let stopCode: String
    let routes: String?
    let distanceMeters: Int?
}

struct SharedArrival: Identifiable {
    var id: String { "\(routeShortName)-\(arrivalTime)-\(waitTime)" }
    let routeShortName: String
    let headsign: String
    let arrivalTime: String
    let waitTime: Int
    let routeColorHex: String
}

enum SharedRailStatusSeverity: Int {
    case normal = 0
    case warning = 1
    case alert = 2
}
