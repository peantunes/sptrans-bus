import Foundation

struct Arrival: Identifiable {
    let id = UUID()
    let tripId: String
    let routeId: String
    let routeShortName: String
    let routeLongName: String
    let headsign: String
    let arrivalTime: String
    let departureTime: String
    let stopId: Int
    let stopSequence: Int
    let routeType: Int
    let routeColor: String
    let routeTextColor: String
    let frequency: Int?
    let waitTime: Int
    var isLiveFromOlhoVivo: Bool = false
    let serviceDate: String?
    let scheduledTimestamp: Int?

    init(
        tripId: String,
        routeId: String,
        routeShortName: String,
        routeLongName: String,
        headsign: String,
        arrivalTime: String,
        departureTime: String,
        stopId: Int,
        stopSequence: Int,
        routeType: Int,
        routeColor: String,
        routeTextColor: String,
        frequency: Int?,
        waitTime: Int,
        isLiveFromOlhoVivo: Bool = false,
        serviceDate: String? = nil,
        scheduledTimestamp: Int? = nil
    ) {
        self.tripId = tripId
        self.routeId = routeId
        self.routeShortName = routeShortName
        self.routeLongName = routeLongName
        self.headsign = headsign
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.stopId = stopId
        self.stopSequence = stopSequence
        self.routeType = routeType
        self.routeColor = routeColor
        self.routeTextColor = routeTextColor
        self.frequency = frequency
        self.waitTime = waitTime
        self.isLiveFromOlhoVivo = isLiveFromOlhoVivo
        self.serviceDate = serviceDate
        self.scheduledTimestamp = scheduledTimestamp
    }

    /// Returns a color-coded wait time status
    var waitTimeStatus: WaitTimeStatus {
        switch waitTime {
        case 0...3: return .arriving
        case 4...10: return .soon
        default: return .scheduled
        }
    }

    /// Formatted wait time string
    var formattedWaitTime: String {
        if waitTime <= 0 {
            return "Now"
        } else if waitTime == 1 {
            return "1 min"
        } else {
            return "\(waitTime) min"
        }
    }

    /// Stable key for UI selection comparisons.
    var selectionKey: String {
        "\(tripId)|\(arrivalTime)|\(waitTime)"
    }
}

enum WaitTimeStatus {
    case arriving   // 0-3 min (red/urgent)
    case soon       // 4-10 min (yellow/warning)
    case scheduled  // 10+ min (green/normal)
}
