import Foundation
import SwiftData

@Model
final class GTFSStopTimeModel {
    var tripId: String
    var arrivalTime: String
    var departureTime: String
    var stopId: Int
    var stopSequence: Int

    init(
        tripId: String,
        arrivalTime: String,
        departureTime: String,
        stopId: Int,
        stopSequence: Int
    ) {
        self.tripId = tripId
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.stopId = stopId
        self.stopSequence = stopSequence
    }
}
