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

extension WatchTransitSnapshot {
    init(sharedSnapshot: SharedTransitSnapshot) {
        self.generatedAt = sharedSnapshot.generatedAt
        self.railLines = sharedSnapshot.railLines.map {
            WatchRailLineSnapshot(
                id: $0.id,
                source: $0.source,
                lineNumber: $0.lineNumber,
                lineName: $0.lineName,
                status: $0.status,
                detail: $0.detail,
                statusColorHex: $0.statusColorHex,
                lineColorHex: $0.lineColorHex,
                severityRawValue: $0.severityRawValue,
                isFavorite: $0.isFavorite
            )
        }
        self.nearbyStops = sharedSnapshot.nearbyStops.map {
            WatchStopSnapshot(
                stopId: $0.stopId,
                stopName: $0.stopName,
                latitude: $0.latitude,
                longitude: $0.longitude,
                stopCode: $0.stopCode,
                routes: $0.routes,
                distanceMeters: $0.distanceMeters
            )
        }
        self.arrivalsByStopID = sharedSnapshot.arrivalsByStopID.mapValues { arrivals in
            arrivals.map {
                WatchArrivalSnapshot(
                    routeShortName: $0.routeShortName,
                    headsign: $0.headsign,
                    arrivalTime: $0.arrivalTime,
                    waitTime: $0.waitTime,
                    routeColorHex: $0.routeColorHex
                )
            }
        }
    }
}
