import Foundation
import SwiftData

@Model
final class GTFSShapePointModel {
    var shapeId: String
    var shapePtLat: Double
    var shapePtLon: Double
    var shapePtSequence: Int

    init(
        shapeId: String,
        shapePtLat: Double,
        shapePtLon: Double,
        shapePtSequence: Int
    ) {
        self.shapeId = shapeId
        self.shapePtLat = shapePtLat
        self.shapePtLon = shapePtLon
        self.shapePtSequence = shapePtSequence
    }
}
