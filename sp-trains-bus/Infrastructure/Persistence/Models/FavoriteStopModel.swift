import Foundation
import SwiftData

@Model
final class FavoriteStopModel {
    @Attribute(.unique) var stopId: Int
    var stopName: String
    var latitude: Double
    var longitude: Double
    var stopSequence: Int
    var stopCode: String
    var wheelchairBoarding: Int
    var createdAt: Date

    init(
        stopId: Int,
        stopName: String,
        latitude: Double,
        longitude: Double,
        stopSequence: Int,
        stopCode: String,
        wheelchairBoarding: Int,
        createdAt: Date = Date()
    ) {
        self.stopId = stopId
        self.stopName = stopName
        self.latitude = latitude
        self.longitude = longitude
        self.stopSequence = stopSequence
        self.stopCode = stopCode
        self.wheelchairBoarding = wheelchairBoarding
        self.createdAt = createdAt
    }
}
