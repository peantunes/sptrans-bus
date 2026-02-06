import Foundation
import SwiftData

@Model
final class GTFSStopModel {
    @Attribute(.unique) var stopId: Int
    var stopCode: String
    var stopName: String
    var stopLat: Double
    var stopLon: Double
    var wheelchairBoarding: Int

    init(
        stopId: Int,
        stopCode: String,
        stopName: String,
        stopLat: Double,
        stopLon: Double,
        wheelchairBoarding: Int
    ) {
        self.stopId = stopId
        self.stopCode = stopCode
        self.stopName = stopName
        self.stopLat = stopLat
        self.stopLon = stopLon
        self.wheelchairBoarding = wheelchairBoarding
    }
}
