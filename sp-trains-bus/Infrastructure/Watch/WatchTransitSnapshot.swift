import Foundation

struct WatchTransitSnapshot: Codable {
    var generatedAt: Date
    var railLines: [WatchRailLineSnapshot]
    var nearbyStops: [WatchStopSnapshot]
    var arrivalsByStopID: [String: [WatchArrivalSnapshot]]

    static let empty = WatchTransitSnapshot(
        generatedAt: .distantPast,
        railLines: [],
        nearbyStops: [],
        arrivalsByStopID: [:]
    )
}

struct WatchRailLineSnapshot: Codable, Identifiable {
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

struct WatchStopSnapshot: Codable, Identifiable {
    var id: Int { stopId }
    let stopId: Int
    let stopName: String
    let latitude: Double
    let longitude: Double
    let stopCode: String
    let routes: String?
    let distanceMeters: Int?
}

struct WatchArrivalSnapshot: Codable, Identifiable {
    var id: String { "\(routeShortName)-\(arrivalTime)-\(waitTime)" }
    let routeShortName: String
    let headsign: String
    let arrivalTime: String
    let waitTime: Int
    let routeColorHex: String
}
