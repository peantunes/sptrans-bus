import Foundation

struct PlanResponse: Decodable {
    let result: PlanResultDTO
}

struct PlanResultDTO: Decodable {
    let alternatives: [PlanAlternativeDTO]
    let rankingPriority: String?
    // Journey planner v2 (absent from the legacy payload).
    let origin: PlanStopDTO?
    let destination: PlanStopDTO?
    let departure: PlanDepartureDTO?
    let walk: PlanWalkOptionDTO?

    private enum CodingKeys: String, CodingKey {
        case alternatives, rankingPriority, origin, destination, departure, walk
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        alternatives = try container.decode([PlanAlternativeDTO].self, forKey: .alternatives)
        rankingPriority = container.decodeLossyString(forKey: .rankingPriority)
        // Optional v2 blocks never fail the whole plan.
        origin = try? container.decodeIfPresent(PlanStopDTO.self, forKey: .origin)
        destination = try? container.decodeIfPresent(PlanStopDTO.self, forKey: .destination)
        departure = try? container.decodeIfPresent(PlanDepartureDTO.self, forKey: .departure)
        walk = try? container.decodeIfPresent(PlanWalkOptionDTO.self, forKey: .walk)
    }
}

struct PlanDepartureDTO: Decodable {
    let date: String?
    let time: String?
    let timestamp: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case date, time, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = container.decodeLossyString(forKey: .date)
        time = container.decodeLossyString(forKey: .time)
        timestamp = container.decodeLossyDouble(forKey: .timestamp)
    }
}

/// Walk-only option. Decoding fails (and the option is dropped) without distance and duration.
struct PlanWalkOptionDTO: Decodable {
    let distanceMeters: Double
    let durationMinutes: Int
    let arrivalTime: String?
    let arrivalTimestamp: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case distanceMeters, durationMinutes, arrivalTime, arrivalTimestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let distance = container.decodeLossyDouble(forKey: .distanceMeters),
              let duration = container.decodeLossyInt(forKey: .durationMinutes) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Walk option without distance or duration"))
        }
        distanceMeters = distance
        durationMinutes = duration
        arrivalTime = container.decodeLossyString(forKey: .arrivalTime)
        arrivalTimestamp = container.decodeLossyDouble(forKey: .arrivalTimestamp)
    }
}

struct PlanAlternativeDTO: Decodable {
    let type: String
    let summary: PlanAlternativeSummaryDTO?
    let legs: [PlanLegDTO]?
    let data: PlanAlternativeDataDTO?
    let segments: [PlanSegmentDTO]?

    private enum CodingKeys: String, CodingKey {
        case type, summary, legs, data, segments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        summary = try container.decodeIfPresent(PlanAlternativeSummaryDTO.self, forKey: .summary)
        legs = try container.decodeIfPresent([PlanLegDTO].self, forKey: .legs)
        data = try? container.decodeIfPresent(PlanAlternativeDataDTO.self, forKey: .data)
        // v2 only; if anything in it is unexpected, the legacy legs still work.
        segments = try? container.decodeIfPresent([PlanSegmentDTO].self, forKey: .segments)
    }
}

struct PlanAlternativeSummaryDTO: Decodable {
    let departureTime: String?
    let arrivalTime: String?
    let legCount: Int?
    let stopCount: Int?
    let lineSummary: String?
    // v2
    let transferCount: Int?
    let startTime: String?
    let endTime: String?
    let startTimestamp: TimeInterval?
    let endTimestamp: TimeInterval?
    let durationMinutes: Int?
    let walkMeters: Double?
    let walkMinutes: Int?

    private enum CodingKeys: String, CodingKey {
        case departureTime, arrivalTime, legCount, stopCount, lineSummary
        case transferCount, startTime, endTime, startTimestamp, endTimestamp, durationMinutes, walkMeters, walkMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        departureTime = container.decodeLossyString(forKey: .departureTime)
        arrivalTime = container.decodeLossyString(forKey: .arrivalTime)
        legCount = container.decodeLossyInt(forKey: .legCount)
        stopCount = container.decodeLossyInt(forKey: .stopCount)
        lineSummary = container.decodeLossyString(forKey: .lineSummary)
        transferCount = container.decodeLossyInt(forKey: .transferCount)
        startTime = container.decodeLossyString(forKey: .startTime)
        endTime = container.decodeLossyString(forKey: .endTime)
        startTimestamp = container.decodeLossyDouble(forKey: .startTimestamp)
        endTimestamp = container.decodeLossyDouble(forKey: .endTimestamp)
        durationMinutes = container.decodeLossyInt(forKey: .durationMinutes)
        walkMeters = container.decodeLossyDouble(forKey: .walkMeters)
        walkMinutes = container.decodeLossyInt(forKey: .walkMinutes)
    }
}

struct PlanAlternativeDataDTO: Decodable {
    let route: PlanRouteDTO?
    let originRoute: PlanRouteDTO?
    let destinationRoute: PlanRouteDTO?
    let tripId: String?
    let originTripId: String?
    let destinationTripId: String?
    let originStopId: Int?
    let destinationStopId: Int?
    let transferStopId: Int?
    let originStop: PlanStopDTO?
    let destinationStop: PlanStopDTO?
    let transferStop: PlanStopDTO?

    private enum CodingKeys: String, CodingKey {
        case route, originRoute, destinationRoute, tripId, originTripId, destinationTripId
        case originStopId, destinationStopId, transferStopId, originStop, destinationStop, transferStop
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        route = try container.decodeIfPresent(PlanRouteDTO.self, forKey: .route)
        originRoute = try container.decodeIfPresent(PlanRouteDTO.self, forKey: .originRoute)
        destinationRoute = try container.decodeIfPresent(PlanRouteDTO.self, forKey: .destinationRoute)
        tripId = container.decodeLossyString(forKey: .tripId)
        originTripId = container.decodeLossyString(forKey: .originTripId)
        destinationTripId = container.decodeLossyString(forKey: .destinationTripId)
        originStopId = container.decodeLossyInt(forKey: .originStopId)
        destinationStopId = container.decodeLossyInt(forKey: .destinationStopId)
        transferStopId = container.decodeLossyInt(forKey: .transferStopId)
        originStop = try container.decodeIfPresent(PlanStopDTO.self, forKey: .originStop)
        destinationStop = try container.decodeIfPresent(PlanStopDTO.self, forKey: .destinationStop)
        transferStop = try container.decodeIfPresent(PlanStopDTO.self, forKey: .transferStop)
    }
}

struct PlanLegDTO: Decodable {
    let route: PlanRouteDTO?
    let tripId: String?
    let originStopId: Int?
    let destinationStopId: Int?
    let originStop: PlanStopDTO?
    let destinationStop: PlanStopDTO?
    // v2
    let mode: String?
    let headsign: String?
    let departureTime: String?
    let arrivalTime: String?
    let departureTimestamp: TimeInterval?
    let arrivalTimestamp: TimeInterval?
    let durationMinutes: Int?
    let stopCount: Int?
    let headwayMinutes: Int?
    let intermediateStops: [PlanStopDTO]?

    private enum CodingKeys: String, CodingKey {
        case route, tripId, originStopId, destinationStopId, originStop, destinationStop
        case mode, headsign, departureTime, arrivalTime, departureTimestamp, arrivalTimestamp
        case durationMinutes, stopCount, headwayMinutes, intermediateStops
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        route = try container.decodeIfPresent(PlanRouteDTO.self, forKey: .route)
        tripId = container.decodeLossyString(forKey: .tripId)
        originStopId = container.decodeLossyInt(forKey: .originStopId)
        destinationStopId = container.decodeLossyInt(forKey: .destinationStopId)
        originStop = try container.decodeIfPresent(PlanStopDTO.self, forKey: .originStop)
        destinationStop = try container.decodeIfPresent(PlanStopDTO.self, forKey: .destinationStop)
        mode = container.decodeLossyString(forKey: .mode)
        headsign = container.decodeLossyString(forKey: .headsign)
        departureTime = container.decodeLossyString(forKey: .departureTime)
        arrivalTime = container.decodeLossyString(forKey: .arrivalTime)
        departureTimestamp = container.decodeLossyDouble(forKey: .departureTimestamp)
        arrivalTimestamp = container.decodeLossyDouble(forKey: .arrivalTimestamp)
        durationMinutes = container.decodeLossyInt(forKey: .durationMinutes)
        stopCount = container.decodeLossyInt(forKey: .stopCount)
        headwayMinutes = container.decodeLossyInt(forKey: .headwayMinutes)
        intermediateStops = try? container.decodeIfPresent([PlanStopDTO].self, forKey: .intermediateStops)
    }
}

/// One step of a v2 journey, in travel order. Walks use from/to; transit steps
/// map, in order, onto the alternative's `legs`.
struct PlanSegmentDTO: Decodable {
    let type: String
    let mode: String?
    let from: PlanStopDTO?
    let to: PlanStopDTO?
    let departureTime: String?
    let arrivalTime: String?
    let durationMinutes: Int?
    let distanceMeters: Double?

    private enum CodingKeys: String, CodingKey {
        case type, mode, from, to, departureTime, arrivalTime, durationMinutes, distanceMeters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        mode = container.decodeLossyString(forKey: .mode)
        from = try? container.decodeIfPresent(PlanStopDTO.self, forKey: .from)
        to = try? container.decodeIfPresent(PlanStopDTO.self, forKey: .to)
        departureTime = container.decodeLossyString(forKey: .departureTime)
        arrivalTime = container.decodeLossyString(forKey: .arrivalTime)
        durationMinutes = container.decodeLossyInt(forKey: .durationMinutes)
        distanceMeters = container.decodeLossyDouble(forKey: .distanceMeters)
    }
}

struct PlanRouteDTO: Decodable {
    let routeId: String?
    let shortName: String?
    let longName: String?
    let color: String?
    let textColor: String?
    let type: Int?

    private enum CodingKeys: String, CodingKey {
        case routeId, shortName, longName, color, textColor, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routeId = container.decodeLossyString(forKey: .routeId)
        shortName = container.decodeLossyString(forKey: .shortName)
        longName = container.decodeLossyString(forKey: .longName)
        color = container.decodeLossyString(forKey: .color)
        textColor = container.decodeLossyString(forKey: .textColor)
        type = container.decodeLossyInt(forKey: .type)
    }
}

/// Stop or point (origin/destination use `lat`/`lon` with no id).
struct PlanStopDTO: Decodable {
    let id: Int?
    let name: String?
    let desc: String?
    let lat: Double?
    let lon: Double?
    let routes: String?
    let distance: Double?
    /// Passing time, on a v2 leg's intermediate stops.
    let time: String?

    var location: Location {
        Location(latitude: lat ?? 0, longitude: lon ?? 0)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, desc, lat, lon, routes, distance, time
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyInt(forKey: .id)
        name = container.decodeLossyString(forKey: .name)
        desc = container.decodeLossyString(forKey: .desc)
        lat = container.decodeLossyDouble(forKey: .lat)
        lon = container.decodeLossyDouble(forKey: .lon)
        routes = container.decodeLossyString(forKey: .routes)
        distance = container.decodeLossyDouble(forKey: .distance)
        time = container.decodeLossyString(forKey: .time)
    }
}

// The PHP API emits ids and numbers as strings or numbers depending on the source
// (e.g. non-numeric GTFS stop ids). Decode leniently instead of failing the plan.
extension KeyedDecodingContainer {
    func decodeLossyInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int(value) }
        return nil
    }

    func decodeLossyDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }

    func decodeLossyString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        return nil
    }
}
