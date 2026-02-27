import Foundation

enum OlhoVivoServiceError: LocalizedError {
    case cloudflareChallengeDetected(statusCode: Int)
    case authenticationFailed
    case invalidAuthResponse
    case invalidHTTPResponse
    case invalidURL
    case invalidPayload
    case upstreamFailure(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .cloudflareChallengeDetected:
            return "Olho Vivo unavailable (Cloudflare challenge)."
        case .authenticationFailed:
            return "Olho Vivo authentication failed."
        case .invalidAuthResponse:
            return "Invalid Olho Vivo authentication response."
        case .invalidHTTPResponse:
            return "Invalid Olho Vivo HTTP response."
        case .invalidURL:
            return "Invalid Olho Vivo URL."
        case .invalidPayload:
            return "Invalid Olho Vivo payload."
        case .upstreamFailure(let statusCode):
            return "Olho Vivo returned HTTP \(statusCode)."
        }
    }

    var isBlocking403: Bool {
        switch self {
        case .cloudflareChallengeDetected(let statusCode):
            return statusCode == 403
        case .upstreamFailure(let statusCode):
            return statusCode == 403
        default:
            return false
        }
    }
}

protocol OlhoVivoArrivalsProviding {
    func getArrivals(for stopId: Int, limit: Int) async throws -> [Arrival]
}

actor OlhoVivoArrivalsService: OlhoVivoArrivalsProviding {
    private static let baseURL = URL(string: "https://api.olhovivo.sptrans.com.br/v2.1")!
    private static let authValiditySeconds: TimeInterval = 20 * 60
    private static let routeColors = [
        "0455A1", "007E5E", "EE372F", "FFD700",
        "9B3894", "CA016B", "01A9A7", "008B8B",
        "F04E23", "083D8B", "00B352", "64748B"
    ]

    private let apiKey: String
    private let session: URLSession
    private let calendar: Calendar
    private let outputFormatter: DateFormatter
    private var authenticatedAt: Date?

    init(
        apiKey: String,
        session: URLSession? = nil,
        calendar: Calendar = .current
    ) {
        self.apiKey = apiKey
        self.calendar = calendar

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpShouldSetCookies = true
            configuration.httpCookieStorage = HTTPCookieStorage()
            self.session = URLSession(configuration: configuration)
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        self.outputFormatter = formatter
    }

    func getArrivals(for stopId: Int, limit: Int) async throws -> [Arrival] {
        guard stopId > 0, limit > 0 else { return [] }

        try await ensureAuthenticated()

        let (data, response) = try await request(
            method: "GET",
            path: "/Previsao/Parada",
            queryItems: [URLQueryItem(name: "codigoParada", value: "\(stopId)")]
        )

        guard (200...299).contains(response.statusCode) else {
            throw OlhoVivoServiceError.upstreamFailure(statusCode: response.statusCode)
        }

        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(OlhoVivoPrevisaoParadaResponse.self, from: data) else {
            throw OlhoVivoServiceError.invalidPayload
        }

        return mapArrivals(payload: payload, stopId: stopId, limit: limit)
    }

    private func ensureAuthenticated() async throws {
        if let authenticatedAt,
           Date().timeIntervalSince(authenticatedAt) < Self.authValiditySeconds {
            return
        }

        let (data, response) = try await request(
            method: "POST",
            path: "/Login/Autenticar",
            queryItems: [URLQueryItem(name: "token", value: apiKey)]
        )

        guard (200...299).contains(response.statusCode) else {
            throw OlhoVivoServiceError.upstreamFailure(statusCode: response.statusCode)
        }

        let normalized = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized == "true" {
            authenticatedAt = Date()
            return
        }

        if normalized == "false" {
            throw OlhoVivoServiceError.authenticationFailed
        }

        if let boolValue = try? JSONDecoder().decode(Bool.self, from: data), boolValue {
            authenticatedAt = Date()
            return
        }

        throw OlhoVivoServiceError.invalidAuthResponse
    }

    private func request(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> (Data, HTTPURLResponse) {
        let endpoint = Self.baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw OlhoVivoServiceError.invalidURL
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw OlhoVivoServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")
        request.setValue("DueSP-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OlhoVivoServiceError.invalidHTTPResponse
        }

        if isCloudflareChallenge(data: data, response: httpResponse) {
            throw OlhoVivoServiceError.cloudflareChallengeDetected(statusCode: httpResponse.statusCode)
        }

        return (data, httpResponse)
    }

    private func isCloudflareChallenge(data: Data, response: HTTPURLResponse) -> Bool {
        let contentType = response.value(forHTTPHeaderField: "content-type")?.lowercased() ?? ""
        let cfMitigated = response.value(forHTTPHeaderField: "cf-mitigated")?.lowercased() ?? ""
        if cfMitigated == "challenge" {
            return true
        }

        guard contentType.contains("text/html") || response.statusCode == 403 else {
            return false
        }

        let text = String(data: data, encoding: .utf8)?.lowercased() ?? ""
        if text.contains("_cf_chl_opt") { return true }
        if text.contains("just a moment") { return true }
        if text.contains("enable javascript and cookies to continue") { return true }
        if text.contains("cloudflare") { return true }
        return false
    }

    private func mapArrivals(
        payload: OlhoVivoPrevisaoParadaResponse,
        stopId: Int,
        limit: Int
    ) -> [Arrival] {
        guard let stop = payload.p else { return [] }
        let now = Date()
        var arrivals: [Arrival] = []

        for line in stop.l {
            let routeShort = normalizedRouteShortName(line: line)
            guard !routeShort.isEmpty else { continue }

            let routeId = line.cl.map(String.init) ?? routeShort
            let destination = line.lt0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let origin = line.lt1?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let routeLong = [origin, destination]
                .filter { !$0.isEmpty }
                .joined(separator: " -> ")
            let headsign = destination.isEmpty ? routeShort : destination
            let routeColor = colorForRoute(routeShortName: routeShort)

            for vehicle in line.vs {
                guard let timeString = vehicle.t?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let arrivalDate = resolveUpcomingDate(timeString: timeString, now: now) else {
                    continue
                }

                let waitTime = max(0, Int(arrivalDate.timeIntervalSince(now) / 60))
                let prefix = vehicle.p?.stringValue ?? "na"
                let tripId = "ov-\(routeId)-\(prefix)-\(timeString)"

                arrivals.append(
                    Arrival(
                        tripId: tripId,
                        routeId: routeId,
                        routeShortName: routeShort,
                        routeLongName: routeLong.isEmpty ? routeShort : routeLong,
                        headsign: headsign,
                        arrivalTime: outputFormatter.string(from: arrivalDate),
                        departureTime: outputFormatter.string(from: arrivalDate),
                        stopId: stopId,
                        stopSequence: 0,
                        routeType: 3,
                        routeColor: routeColor,
                        routeTextColor: "FFFFFF",
                        frequency: nil,
                        waitTime: waitTime,
                        isLiveFromOlhoVivo: true
                    )
                )
            }
        }

        if arrivals.isEmpty {
            return []
        }

        var seen: Set<String> = []
        let deduplicated = arrivals.filter { arrival in
            let key = "\(arrival.routeShortName)|\(arrival.arrivalTime)|\(arrival.tripId)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        return Array(
            deduplicated
                .sorted(by: { lhs, rhs in
                    if lhs.waitTime == rhs.waitTime {
                        return lhs.routeShortName < rhs.routeShortName
                    }
                    return lhs.waitTime < rhs.waitTime
                })
                .prefix(limit)
        )
    }

    private func normalizedRouteShortName(line: OlhoVivoLinePrediction) -> String {
        let explicit = line.c?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !explicit.isEmpty {
            return explicit
        }

        if let lineCode = line.cl {
            return "\(lineCode)"
        }

        return ""
    }

    private func resolveUpcomingDate(timeString: String, now: Date) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }

        let second = parts.count >= 3 ? (Int(parts[2]) ?? 0) : 0

        guard let dayStart = calendar.dateInterval(of: .day, for: now)?.start,
              let todayDate = calendar.date(
                bySettingHour: hour % 24,
                minute: minute,
                second: second,
                of: dayStart
              ) else {
            return nil
        }

        if todayDate < now,
           let nextDay = calendar.date(byAdding: .day, value: 1, to: todayDate) {
            return nextDay
        }

        return todayDate
    }

    private func colorForRoute(routeShortName: String) -> String {
        let hash = abs(routeShortName.hashValue)
        return Self.routeColors[hash % Self.routeColors.count]
    }
}

private struct OlhoVivoPrevisaoParadaResponse: Decodable {
    let hr: String?
    let p: OlhoVivoParadaPrediction?
}

private struct OlhoVivoParadaPrediction: Decodable {
    let cp: Int?
    let np: String?
    let py: Double?
    let px: Double?
    let l: [OlhoVivoLinePrediction]
}

private struct OlhoVivoLinePrediction: Decodable {
    let c: String?
    let cl: Int?
    let sl: Int?
    let lt0: String?
    let lt1: String?
    let qv: Int?
    let vs: [OlhoVivoVehiclePrediction]
}

private struct OlhoVivoVehiclePrediction: Decodable {
    let p: OlhoVivoFlexibleStringInt?
    let t: String?
    let a: Bool?
    let ta: String?
    let py: Double?
    let px: Double?
}

private struct OlhoVivoFlexibleStringInt: Decodable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            stringValue = "\(intValue)"
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self.stringValue = stringValue
            return
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or int")
        )
    }
}
