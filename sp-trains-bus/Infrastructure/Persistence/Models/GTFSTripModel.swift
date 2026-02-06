import Foundation
import SwiftData

@Model
final class GTFSTripModel {
    @Attribute(.unique) var tripId: String
    var routeId: String
    var serviceId: String
    var tripHeadsign: String
    var directionId: Int
    var shapeId: String

    init(
        tripId: String,
        routeId: String,
        serviceId: String,
        tripHeadsign: String,
        directionId: Int,
        shapeId: String
    ) {
        self.tripId = tripId
        self.routeId = routeId
        self.serviceId = serviceId
        self.tripHeadsign = tripHeadsign
        self.directionId = directionId
        self.shapeId = shapeId
    }
}
