import Foundation

struct SharedTransitAPIService {
    private enum Config {
        static let baseURL = URL(string: "https://sptrans.lolados.app/api")!
        static let defaultLatitude = -23.5505
        static let defaultLongitude = -46.6333
        static let nearbyLimit = 6
        static let arrivalsLimit = 8
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchSnapshot(preferredStopID: Int?, favoriteLineIDs: Set<String> = []) async -> SharedTransitSnapshot {
        async let railLinesTask = fetchRailLines(favoriteLineIDs: favoriteLineIDs)
        async let nearbyStopsTask = fetchNearbyStops()

        let railLines = await railLinesTask
        let nearbyStops = prioritizeNearbyStops(await nearbyStopsTask, preferredStopID: preferredStopID)
        let arrivalStops = Array(nearbyStops.prefix(6))
        let arrivalsByStopID = await fetchArrivals(for: arrivalStops)

        return SharedTransitSnapshot(
            generatedAt: Date(),
            railLines: railLines,
            nearbyStops: nearbyStops,
            arrivalsByStopID: arrivalsByStopID
        )
    }

    private func prioritizeNearbyStops(_ stops: [SharedStop], preferredStopID: Int?) -> [SharedStop] {
        guard let preferredStopID,
              let preferredIndex = stops.firstIndex(where: { $0.stopId == preferredStopID }) else {
            return stops
        }

        var ordered = stops
        let preferred = ordered.remove(at: preferredIndex)
        ordered.insert(preferred, at: 0)
        return ordered
    }

    private func fetchRailLines(favoriteLineIDs: Set<String>) async -> [SharedRailLine] {
        do {
            let response: SharedRailStatusResponseDTO = try await request(endpoint: .metroStatus)

            let metroLines = mapRailLines(response.metro.lines, source: "metro", favoriteLineIDs: favoriteLineIDs)
            let cptmLines = mapRailLines(response.cptm.lines, source: "cptm", favoriteLineIDs: favoriteLineIDs)
            return metroLines + cptmLines
        } catch {
            return []
        }
    }

    private func fetchNearbyStops() async -> [SharedStop] {
        do {
            let response: SharedNearbyStopsResponseDTO = try await request(
                endpoint: .nearby(
                    lat: Config.defaultLatitude,
                    lon: Config.defaultLongitude,
                    limit: Config.nearbyLimit
                )
            )

            return response.stops
                .map {
                    SharedStop(
                        stopId: $0.id,
                        stopName: $0.name,
                        latitude: $0.lat,
                        longitude: $0.lon,
                        stopCode: "",
                        routes: $0.routes,
                        distanceMeters: Int($0.distance.rounded())
                    )
                }
                .sorted { ($0.distanceMeters ?? Int.max) < ($1.distanceMeters ?? Int.max) }
        } catch {
            return []
        }
    }

    private func fetchArrivals(for stops: [SharedStop]) async -> [String: [SharedArrival]] {
        await withTaskGroup(of: (Int, [SharedArrival]?).self, returning: [String: [SharedArrival]].self) { group in
            for stop in stops {
                group.addTask {
                    let arrivals = await fetchArrivals(stopID: stop.stopId)
                    return (stop.stopId, arrivals)
                }
            }

            var result: [String: [SharedArrival]] = [:]
            for await (stopID, arrivals) in group {
                if let arrivals {
                    result["\(stopID)"] = arrivals
                }
            }
            return result
        }
    }

    private func fetchArrivals(stopID: Int) async -> [SharedArrival]? {
        do {
            let response: SharedArrivalsResponseDTO = try await request(
                endpoint: .arrivals(stopID: stopID, limit: Config.arrivalsLimit)
            )
            let arrivals = response.arrivals
                .sorted { $0.waitTime < $1.waitTime }
                .prefix(8)
                .map {
                    SharedArrival(
                        routeShortName: $0.routeShortName,
                        headsign: $0.headsign,
                        arrivalTime: $0.arrivalTime,
                        waitTime: $0.waitTime,
                        routeColorHex: $0.routeColor
                    )
                }
            return Array(arrivals)
        } catch {
            return nil
        }
    }

    private func request<T: Decodable>(endpoint: SharedTransitAPIEndpoint) async throws -> T {
        var components = URLComponents(url: Config.baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        components?.queryItems = endpoint.parameters

        guard let url = components?.url else {
            throw SharedTransitAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SharedTransitAPIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    private func mapRailLines(_ lines: [SharedRailLineStatusDTO], source: String, favoriteLineIDs: Set<String>) -> [SharedRailLine] {
        lines
            .enumerated()
            .map { index, line in
                let lineNumber = normalizedLineNumber(line.lineNumber)
                let lineName = line.lineName.trimmingCharacters(in: .whitespacesAndNewlines)
                let status = line.status.trimmingCharacters(in: .whitespacesAndNewlines)
                let severity = statusSeverity(status: status)
                let normalizedStatusColor = normalizedHex(line.statusColor) ?? fallbackStatusColorHex(status: status, severity: severity)

                let fallbackIdentifier = "idx\(index)"
                let identifier = "\(source)-\(lineNumber.isEmpty ? fallbackIdentifier : lineNumber)-\(lineName.isEmpty ? fallbackIdentifier : lineName)"

                return SharedRailLine(
                    id: identifier,
                    source: source,
                    lineNumber: lineNumber,
                    lineName: lineName.isEmpty ? "Linha \(lineNumber)" : lineName,
                    status: status.isEmpty ? "Status indisponivel" : status,
                    detail: line.statusDetail,
                    statusColorHex: normalizedStatusColor,
                    lineColorHex: lineColorHex(source: source, lineNumber: lineNumber),
                    severityRawValue: severity.rawValue,
                    isFavorite: favoriteLineIDs.contains(identifier)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite && !rhs.isFavorite
                }

                let lhsNumber = Int(lhs.lineNumber) ?? Int.max
                let rhsNumber = Int(rhs.lineNumber) ?? Int.max
                if lhsNumber == rhsNumber {
                    return lhs.lineName < rhs.lineName
                }
                return lhsNumber < rhsNumber
            }
    }

    private func normalizedLineNumber(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "Linha ", with: "")
            .replacingOccurrences(of: "Line ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedHex(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("#") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private func lineColorHex(source: String, lineNumber: String) -> String {
        switch source.lowercased() {
        case "metro":
            switch lineNumber {
            case "1": return "0455A1"
            case "2": return "007E5E"
            case "3": return "EE372F"
            case "4": return "FFD700"
            case "5": return "9B3894"
            case "15": return "A9A9A9"
            default: return "64748B"
            }
        case "cptm":
            switch lineNumber {
            case "7": return "CA016B"
            case "8": return "97A098"
            case "9": return "01A9A7"
            case "10": return "008B8B"
            case "11": return "F04E23"
            case "12": return "083D8B"
            case "13": return "00B352"
            default: return "64748B"
            }
        default:
            return "64748B"
        }
    }

    private func statusSeverity(status: String) -> SharedRailStatusSeverity {
        let normalized = status
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        if normalized.contains("normal") || normalized.contains("operacao normal") {
            return .normal
        }

        let alertTerms = [
            "interrompid", "paralisad", "suspens", "encerrad",
            "sem operacao", "inoperante", "falha grave", "indisponivel"
        ]
        if alertTerms.contains(where: { normalized.contains($0) }) {
            return .alert
        }

        let warningTerms = [
            "velocidade reduzida", "atencao", "parcial",
            "lento", "lentidao", "restricao", "restrição", "monitorad",
            "intermitente", "oscilacao", "oscilação", "alerta", "desvio"
        ]
        if warningTerms.contains(where: { normalized.contains($0) }) {
            return .warning
        }

        return .warning
    }

    private func fallbackStatusColorHex(status: String, severity: SharedRailStatusSeverity) -> String {
        let normalized = status
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let partialTerms = ["parcial", "normalizacao", "interferencia", "manutencao"]
        if partialTerms.contains(where: { normalized.contains($0) }) {
            return "FF8C00"
        }

        let reducedTerms = ["velocidade reduzida", "atencao", "lento", "lentidao"]
        if reducedTerms.contains(where: { normalized.contains($0) }) {
            return "FFB800"
        }

        switch severity {
        case .normal:
            return "00E000"
        case .warning:
            return "FFB800"
        case .alert:
            return "FF3B30"
        }
    }
}

private enum SharedTransitAPIEndpoint {
    case metroStatus
    case nearby(lat: Double, lon: Double, limit: Int)
    case arrivals(stopID: Int, limit: Int)

    var path: String {
        switch self {
        case .metroStatus:
            return "/metro_cptm.php"
        case .nearby:
            return "/nearby.php"
        case .arrivals:
            return "/arrivals.php"
        }
    }

    var parameters: [URLQueryItem] {
        switch self {
        case .metroStatus:
            return []
        case .nearby(let lat, let lon, let limit):
            return [
                URLQueryItem(name: "lat", value: "\(lat)"),
                URLQueryItem(name: "lon", value: "\(lon)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        case .arrivals(let stopID, let limit):
            return [
                URLQueryItem(name: "stop_id", value: "\(stopID)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        }
    }
}

private enum SharedTransitAPIError: Error {
    case invalidURL
    case invalidResponse
}

private struct SharedRailStatusResponseDTO: Decodable {
    let metro: SharedRailSourceStatusDTO
    let cptm: SharedRailSourceStatusDTO
}

private struct SharedRailSourceStatusDTO: Decodable {
    let lines: [SharedRailLineStatusDTO]
}

private struct SharedRailLineStatusDTO: Decodable {
    let lineNumber: String
    let lineName: String
    let status: String
    let statusDetail: String
    let statusColor: String
}

private struct SharedNearbyStopsResponseDTO: Decodable {
    let stops: [SharedNearbyStopDTO]
}

private struct SharedNearbyStopDTO: Decodable {
    let id: Int
    let name: String
    let lat: Double
    let lon: Double
    let routes: String?
    let distance: Double
}

private struct SharedArrivalsResponseDTO: Decodable {
    let arrivals: [SharedArrivalDTO]
}

private struct SharedArrivalDTO: Decodable {
    let routeShortName: String
    let headsign: String
    let arrivalTime: String
    let waitTime: Int
    let routeColor: String
}
