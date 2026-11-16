import Foundation

struct JourneyRailLineStatus: Identifiable {
    let source: String
    let lineNumber: String
    let lineName: String
    let status: String
    let detail: String
    let updatedAt: String?
    let fetchedAt: Date?
    let available: Bool

    var id: String { "\(source)-\(lineNumber)" }
    var title: String { "\(source == "metro" ? "Metrô" : "CPTM") · \(lineNumber) · \(lineName)" }
    var hasKnownStatus: Bool {
        let value = Self.normalized(status)
        return !value.isEmpty && !["status indisponivel", "informacao indisponivel", "sem informacao", "unavailable", "unknown"].contains(value)
    }

    var isDisrupted: Bool {
        let value = Self.normalized(status)
        return hasKnownStatus && !["operacao normal", "normal", "situacao normal", "normal operation", "good service"].contains(value)
    }

    func isStale(at now: Date = Date()) -> Bool {
        guard available, let fetchedAt else { return true }
        return now.timeIntervalSince(fetchedAt) > 45 * 60 || fetchedAt.timeIntervalSince(now) > 5 * 60
    }

    func matches(_ leg: TripPlanLeg) -> Bool {
        guard leg.railSource == source, let route = leg.route else { return false }
        let number = Int(lineNumber)
        // Match an entire line identifier, never arbitrary digits in a bus route
        // or a destination such as "Metrô Santana".
        for identifier in [route.shortName, route.routeId] {
            let normalized = Self.normalized(identifier)
            let tokens = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            let numbers = tokens.compactMap { token -> Int? in
                Int(token.hasPrefix("l") ? String(token.dropFirst()) : token)
            }
            if numbers.count == 1, numbers.first == number { return true }
        }
        let name = Self.normalized(lineName)
        guard !name.isEmpty else { return false }
        return [route.shortName, route.routeId].contains { Self.normalized($0) == name }
    }

    nonisolated static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension TripPlanLeg {
    var railSource: String? {
        if mode == "bus" || route?.type == 3 { return nil }
        if mode == "metro" || route?.type == 1 { return "metro" }
        if mode == "rail" || route?.type == 0 || route?.type == 2 { return "cptm" }
        let identifier = JourneyRailLineStatus.normalized("\(route?.shortName ?? "") \(route?.routeId ?? "")")
        if identifier.contains("metro") { return "metro" }
        if identifier.contains("cptm") { return "cptm" }
        return nil
    }
}

struct JourneyLiveArrival {
    let expectedAt: Date
    let checkedAt: Date
    let headsign: String

    var expectedTimeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: expectedAt)
    }

    func isFresh(at now: Date = Date()) -> Bool {
        now.timeIntervalSince(checkedAt) < 90 && expectedAt >= now
    }

    static func match(_ arrivals: [Arrival], leg: TripPlanLeg, now: Date = Date()) -> JourneyLiveArrival? {
        guard leg.railSource == nil, let route = leg.route,
              let timestamp = leg.departureTimestamp,
              (0...3600).contains(timestamp - now.timeIntervalSince1970),
              let headsign = leg.headsign, !headsign.isEmpty else { return nil }
        let normalized = JourneyRailLineStatus.normalized
        let matches = arrivals.filter {
            $0.isLiveFromOlhoVivo && $0.stopId == leg.originStopId && (0...60).contains($0.waitTime)
                && normalized($0.routeShortName) == normalized(route.shortName)
                && normalized($0.headsign) == normalized(headsign)
        }
        guard let arrival = matches.min(by: { $0.waitTime < $1.waitTime }) else { return nil }
        return JourneyLiveArrival(expectedAt: now.addingTimeInterval(Double(arrival.waitTime) * 60),
                                  checkedAt: now, headsign: arrival.headsign)
    }
}
