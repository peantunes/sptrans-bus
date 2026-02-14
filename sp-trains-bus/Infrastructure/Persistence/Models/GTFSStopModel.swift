import Foundation
import SwiftData

@Model
final class GTFSStopModel {
    @Attribute(.unique) var stopId: Int
    var stopCode: String
    var stopName: String
    var stopLat: Double
    var stopLon: Double
    var routes: String?
    var wheelchairBoarding: Int

    init(
        stopId: Int,
        stopCode: String,
        stopName: String,
        stopLat: Double,
        stopLon: Double,
        routes: String?,
        wheelchairBoarding: Int
    ) {
        self.stopId = stopId
        self.stopCode = stopCode
        self.stopName = stopName
        self.stopLat = stopLat
        self.stopLon = stopLon
        self.routes = routes
        self.wheelchairBoarding = wheelchairBoarding
    }
}
