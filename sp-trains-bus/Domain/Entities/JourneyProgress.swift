import Foundation

/// A planned journey laid out in time and space, for tracking where the traveller should be.
struct JourneyTimeline {
    struct Point {
        let name: String
        let location: Location?
        let time: Date?
    }

    enum Step {
        case walk(from: Point, to: Point, toDestination: Bool)
        case ride(leg: TripPlanLeg, stops: [Point])

        var start: Date? {
            switch self {
            case .walk(let from, _, _): return from.time
            case .ride(_, let stops): return stops.first?.time
            }
        }

        var end: Date? {
            switch self {
            case .walk(_, let to, _): return to.time
            case .ride(_, let stops): return stops.last?.time
            }
        }
    }

    let steps: [Step]
    let destinationName: String
    let destination: Location?
    let arrival: Date?

    /// [serviceDay] is any moment of the São Paulo service day the GTFS times belong to.
    init(alternative: TripPlanAlternative, serviceDay: Date, destinationName: String, destination: Location?) {
        let midnight = Self.serviceMidnight(serviceDay)
        func at(_ time: String?) -> Date? { Self.date(time, midnight: midnight) }

        let legs = alternative.vehicleLegs
        var steps: [Step] = []
        let segments: [TripPlanSegment] = alternative.segments.isEmpty ? legs.indices.map { .transit($0) } : alternative.segments
        for (index, segment) in segments.enumerated() {
            switch segment {
            case .walk(let walk):
                steps.append(.walk(
                    from: Point(name: walk.fromLabel, location: walk.fromLocation, time: at(walk.departureTime)),
                    to: Point(name: walk.toLabel, location: walk.toLocation, time: at(walk.arrivalTime)),
                    toDestination: index == segments.count - 1
                ))
            case .transit(let legIndex):
                guard legs.indices.contains(legIndex) else { continue }
                let leg = legs[legIndex]
                var stops: [Point] = []
                if let board = leg.originStop {
                    stops.append(Point(name: board.stopName, location: board.location, time: at(leg.departureTime)))
                }
                for (i, stop) in (leg.intermediateStops ?? []).enumerated() {
                    let time = leg.intermediateStopTimes.indices.contains(i) ? leg.intermediateStopTimes[i] : nil
                    stops.append(Point(name: stop.stopName, location: stop.location, time: at(time)))
                }
                if let alight = leg.destinationStop {
                    stops.append(Point(name: alight.stopName, location: alight.location, time: at(leg.arrivalTime)))
                }
                guard stops.count >= 2 else { continue }
                steps.append(.ride(leg: leg, stops: stops))
            }
        }
        self.steps = steps
        self.destinationName = destinationName
        self.destination = destination
        self.arrival = at(alternative.endTime ?? alternative.arrivalTime) ?? steps.last?.end
    }

    static func serviceMidnight(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar.startOfDay(for: date)
    }

    /// GTFS "HH:MM[:SS]" (hours may pass 24) on the service day.
    static func date(_ time: String?, midnight: Date) -> Date? {
        guard let time else { return nil }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        let seconds = parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
        return midnight.addingTimeInterval(TimeInterval(seconds))
    }
}

/// Where the traveller is on the journey and what to do next.
struct JourneyProgress: Equatable {
    enum Phase: String, Equatable {
        case walking
        case waiting
        case riding
        case arrived
    }

    let phase: Phase
    let stepIndex: Int
    let stepCount: Int
    let title: String
    let subtitle: String
    let lineName: String?
    let lineColorHex: String?
    let lineTextHex: String?
    let modeSymbol: String
    let nextEventDate: Date
    let arrivalDate: Date
    let stopsLeft: Int?
    /// Boarding or transfer stop the traveller is at (for alternatives), when waiting.
    let stopLocation: Location?
    let usesLocation: Bool
}

enum JourneyProgressCalculator {
    /// GPS fixes worse than this are ignored; the timetable decides.
    static let maxAccuracy: Double = 120
    static let atStopRadius: Double = 90
    static let onRouteRadius: Double = 220
    static let arrivedRadius: Double = 120

    static func progress(_ timeline: JourneyTimeline, now: Date, location: Location?, accuracy: Double?) -> JourneyProgress {
        let steps = timeline.steps
        let arrival = timeline.arrival ?? now
        guard !steps.isEmpty else { return arrived(timeline, count: 0, at: arrival, usesLocation: false) }

        if let location, (accuracy ?? 0) <= maxAccuracy, let match = locate(timeline, location: location, now: now) {
            return match
        }
        return byTime(timeline, now: now)
    }

    // MARK: - Location

    private static func locate(_ timeline: JourneyTimeline, location: Location, now: Date) -> JourneyProgress? {
        let steps = timeline.steps
        let arrival = timeline.arrival ?? now
        if let destination = timeline.destination, location.distance(to: destination) <= arrivedRadius {
            return arrived(timeline, count: steps.count, at: arrival, usesLocation: true)
        }
        // Later steps win, but never one that starts more than 15 minutes from now (routes can pass the same place twice).
        for index in steps.indices.reversed() {
            if let start = steps[index].start, start > now.addingTimeInterval(15 * 60) { continue }
            guard case .ride(let leg, let stops) = steps[index] else { continue }
            let distances = stops.map { $0.location.map { location.distance(to: $0) } ?? .greatestFiniteMagnitude }
            guard let nearest = distances.indices.min(by: { distances[$0] < distances[$1] }) else { continue }
            if nearest == 0, distances[0] <= atStopRadius {
                return waiting(timeline, index: index, leg: leg, stops: stops, now: now, usesLocation: true)
            }
            if nearest > 0, distances[nearest] <= onRouteRadius {
                if nearest == stops.count - 1 {
                    // At the alighting stop: the next step starts.
                    return index + 1 < steps.count
                        ? progress(for: index + 1, timeline: timeline, now: now, usesLocation: true)
                        : arrived(timeline, count: steps.count, at: arrival, usesLocation: true)
                }
                return riding(timeline, index: index, leg: leg, stops: stops, nextStop: nearest + 1, now: now, usesLocation: true)
            }
        }
        return nil
    }

    // MARK: - Timetable

    private static func byTime(_ timeline: JourneyTimeline, now: Date) -> JourneyProgress {
        let steps = timeline.steps
        for index in steps.indices {
            if let end = steps[index].end, end <= now { continue }
            return progress(for: index, timeline: timeline, now: now, usesLocation: false)
        }
        return arrived(timeline, count: steps.count, at: timeline.arrival ?? now, usesLocation: false)
    }

    private static func progress(for index: Int, timeline: JourneyTimeline, now: Date, usesLocation: Bool) -> JourneyProgress {
        switch timeline.steps[index] {
        case .walk(let from, let to, let toDestination):
            return walking(timeline, index: index, from: from, to: to, toDestination: toDestination, now: now, usesLocation: usesLocation)
        case .ride(let leg, let stops):
            if let start = stops.first?.time, now < start {
                return waiting(timeline, index: index, leg: leg, stops: stops, now: now, usesLocation: usesLocation)
            }
            let next = stops.indices.first { i in i > 0 && (stops[i].time.map { $0 > now } ?? false) } ?? stops.count - 1
            return riding(timeline, index: index, leg: leg, stops: stops, nextStop: next, now: now, usesLocation: usesLocation)
        }
    }

    // MARK: - States

    private static func walking(_ timeline: JourneyTimeline, index: Int, from: JourneyTimeline.Point, to: JourneyTimeline.Point,
                                toDestination: Bool, now: Date, usesLocation: Bool) -> JourneyProgress {
        let target = toDestination ? timeline.destinationName : to.name
        var subtitle = ""
        if index + 1 < timeline.steps.count, case .ride(let leg, let stops) = timeline.steps[index + 1] {
            subtitle = String(format: NSLocalizedString("Board %@ at %@", comment: ""), lineName(leg), clock(stops.first?.time))
        } else if let arrival = timeline.arrival {
            subtitle = String(format: NSLocalizedString("Arrive at %@", comment: ""), clock(arrival))
        }
        return JourneyProgress(
            phase: .walking, stepIndex: index, stepCount: timeline.steps.count,
            title: String(format: NSLocalizedString("Walk to %@", comment: ""), target), subtitle: subtitle,
            lineName: nil, lineColorHex: nil, lineTextHex: nil, modeSymbol: "figure.walk",
            nextEventDate: to.time ?? now, arrivalDate: timeline.arrival ?? now, stopsLeft: nil,
            stopLocation: nil, usesLocation: usesLocation
        )
    }

    private static func waiting(_ timeline: JourneyTimeline, index: Int, leg: TripPlanLeg, stops: [JourneyTimeline.Point],
                                now: Date, usesLocation: Bool) -> JourneyProgress {
        var detail = String(format: NSLocalizedString("at %@", comment: ""), stops[0].name)
        if let headsign = leg.headsign, !headsign.isEmpty {
            detail += " · " + String(format: NSLocalizedString("towards %@", comment: ""), headsign)
        }
        return JourneyProgress(
            phase: .waiting, stepIndex: index, stepCount: timeline.steps.count,
            title: String(format: NSLocalizedString("Board %@", comment: ""), lineName(leg)), subtitle: detail,
            lineName: lineName(leg), lineColorHex: leg.route?.color, lineTextHex: leg.route?.textColor,
            modeSymbol: leg.systemImage, nextEventDate: stops[0].time ?? now, arrivalDate: timeline.arrival ?? now,
            stopsLeft: stops.count - 1, stopLocation: stops[0].location, usesLocation: usesLocation
        )
    }

    private static func riding(_ timeline: JourneyTimeline, index: Int, leg: TripPlanLeg, stops: [JourneyTimeline.Point],
                               nextStop: Int, now: Date, usesLocation: Bool) -> JourneyProgress {
        let alight = stops[stops.count - 1]
        let left = max(0, stops.count - 1 - nextStop) + 1
        let subtitle = nextStop < stops.count - 1
            ? String(format: NSLocalizedString("Next: %@ · %lld stops left", comment: ""), stops[nextStop].name, left)
            : NSLocalizedString("Next stop", comment: "")
        return JourneyProgress(
            phase: .riding, stepIndex: index, stepCount: timeline.steps.count,
            title: String(format: NSLocalizedString("Get off at %@", comment: ""), alight.name), subtitle: subtitle,
            lineName: lineName(leg), lineColorHex: leg.route?.color, lineTextHex: leg.route?.textColor,
            modeSymbol: leg.systemImage, nextEventDate: alight.time ?? now, arrivalDate: timeline.arrival ?? now,
            stopsLeft: left, stopLocation: nil, usesLocation: usesLocation
        )
    }

    private static func arrived(_ timeline: JourneyTimeline, count: Int, at date: Date, usesLocation: Bool) -> JourneyProgress {
        JourneyProgress(
            phase: .arrived, stepIndex: max(0, count - 1), stepCount: count,
            title: NSLocalizedString("You have arrived", comment: ""), subtitle: timeline.destinationName,
            lineName: nil, lineColorHex: nil, lineTextHex: nil, modeSymbol: "flag.checkered",
            nextEventDate: date, arrivalDate: date, stopsLeft: nil, stopLocation: nil, usesLocation: usesLocation
        )
    }

    private static func lineName(_ leg: TripPlanLeg) -> String {
        let name = leg.route?.shortName ?? ""
        return name.isEmpty ? (leg.route?.routeId ?? NSLocalizedString("Line", comment: "")) : name
    }

    static func clock(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
