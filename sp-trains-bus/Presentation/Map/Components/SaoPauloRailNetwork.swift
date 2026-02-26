import Foundation
import MapKit

enum RailSystem {
    case metro
    case cptm
}

struct RailMapStation: Identifiable {
    let id: String
    let stopId: Int
    let name: String
    let coordinate: CLLocationCoordinate2D
    let system: RailSystem
    let colorHex: String
}

struct RailMapLine: Identifiable {
    let id: String
    let name: String
    let system: RailSystem
    let colorHex: String
    let stations: [RailMapStation]

    var polylineCoordinates: [CLLocationCoordinate2D] {
        stations.map(\.coordinate)
    }
}

struct RailMapAPISource {
    let id: String
    let tripId: String
    let system: RailSystem
    let name: String
    let colorHex: String
}

struct RailNetworkCachePayload: Codable {
    let savedAt: Date
    let lines: [RailMapLineCache]
}

struct RailMapLineCache: Codable {
    let id: String
    let name: String
    let system: String
    let colorHex: String
    let stations: [RailMapStationCache]

    @MainActor
    init(line: RailMapLine) {
        id = line.id
        name = line.name
        system = line.system.cacheValue
        colorHex = line.colorHex
        stations = line.stations.map(RailMapStationCache.init(station:))
    }

    func toRailMapLine() -> RailMapLine? {
        guard let mappedSystem = RailSystem(cacheValue: system) else { return nil }
        return RailMapLine(
            id: id,
            name: name,
            system: mappedSystem,
            colorHex: colorHex,
            stations: stations.map { $0.toRailMapStation(colorHex: colorHex, defaultSystem: mappedSystem) }
        )
    }
}

struct RailMapStationCache: Codable {
    let id: String
    let stopId: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let system: String

    private enum CodingKeys: String, CodingKey {
        case id
        case stopId
        case name
        case latitude
        case longitude
        case system
    }

    @MainActor
    init(station: RailMapStation) {
        id = station.id
        stopId = station.stopId
        name = station.name
        latitude = station.coordinate.latitude
        longitude = station.coordinate.longitude
        system = station.system.cacheValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        stopId = try container.decodeIfPresent(Int.self, forKey: .stopId) ?? syntheticRailStopId(fromStationId: id)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        system = try container.decode(String.self, forKey: .system)
    }

    func toRailMapStation(colorHex: String, defaultSystem: RailSystem) -> RailMapStation {
        let mappedSystem = RailSystem(cacheValue: system) ?? defaultSystem
        return RailMapStation(
            id: id,
            stopId: stopId,
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            system: mappedSystem,
            colorHex: colorHex
        )
    }
}

enum SaoPauloRailNetwork {
    static let fallbackLines: [RailMapLine] = [
        metroLine(
            id: "L1",
            name: "Linha 1 - Azul",
            colorHex: "0455A1",
            stations: [
                ("Jabaquara", -23.6466, -46.6408),
                ("Santa Cruz", -23.5995, -46.6367),
                ("Paraiso", -23.5753, -46.6400),
                ("Sao Joaquim", -23.5616, -46.6397),
                ("Se", -23.5507, -46.6339),
                ("Luz", -23.5363, -46.6339),
                ("Santana", -23.5059, -46.6246),
                ("Tucuruvi", -23.4799, -46.6044)
            ]
        ),
        metroLine(
            id: "L2",
            name: "Linha 2 - Verde",
            colorHex: "007E5E",
            stations: [
                ("Vila Madalena", -23.5466, -46.6906),
                ("Sumare", -23.5508, -46.6790),
                ("Consolacao", -23.5573, -46.6608),
                ("Brigadeiro", -23.5696, -46.6477),
                ("Paraiso", -23.5753, -46.6400),
                ("Ana Rosa", -23.5818, -46.6388),
                ("Santos-Imigrantes", -23.5923, -46.6207),
                ("Vila Prudente", -23.5859, -46.5816)
            ]
        ),
        metroLine(
            id: "L3",
            name: "Linha 3 - Vermelha",
            colorHex: "EE372F",
            stations: [
                ("Palmeiras-Barra Funda", -23.5255, -46.6676),
                ("Republica", -23.5441, -46.6421),
                ("Se", -23.5507, -46.6339),
                ("Bras", -23.5434, -46.6166),
                ("Tatuape", -23.5403, -46.5764),
                ("Corinthians-Itaquera", -23.5421, -46.4712)
            ]
        ),
        metroLine(
            id: "L4",
            name: "Linha 4 - Amarela",
            colorHex: "FFD700",
            stations: [
                ("Luz", -23.5363, -46.6339),
                ("Republica", -23.5441, -46.6421),
                ("Higienopolis-Mackenzie", -23.5489, -46.6521),
                ("Paulista", -23.5550, -46.6622),
                ("Pinheiros", -23.5675, -46.7018),
                ("Butanta", -23.5716, -46.7084),
                ("Vila Sonia", -23.5861, -46.7314)
            ]
        ),
        metroLine(
            id: "L5",
            name: "Linha 5 - Lilas",
            colorHex: "9B3894",
            stations: [
                ("Capao Redondo", -23.6598, -46.7692),
                ("Santo Amaro", -23.6540, -46.7142),
                ("Adolfo Pinheiro", -23.6503, -46.7040),
                ("Alto da Boa Vista", -23.6414, -46.6991),
                ("Borba Gato", -23.6330, -46.6939),
                ("Santa Cruz", -23.5995, -46.6367),
                ("Chacara Klabin", -23.5928, -46.6297)
            ]
        ),
        cptmLine(
            id: "L7",
            name: "Linha 7 - Rubi",
            colorHex: "CA016B",
            stations: [
                ("Jundiai", -23.1861, -46.8845),
                ("Franco da Rocha", -23.3224, -46.7284),
                ("Caieiras", -23.3644, -46.7424),
                ("Perus", -23.4043, -46.7531),
                ("Pirituba", -23.4946, -46.7251),
                ("Lapa", -23.5257, -46.7056),
                ("Palmeiras-Barra Funda", -23.5255, -46.6676),
                ("Luz", -23.5363, -46.6339)
            ]
        ),
        cptmLine(
            id: "L8",
            name: "Linha 8 - Diamante",
            colorHex: "97A098",
            stations: [
                ("Amador Bueno", -23.5348, -47.0662),
                ("Itapevi", -23.5486, -46.9345),
                ("Barueri", -23.5112, -46.8760),
                ("Carapicuiba", -23.5231, -46.8352),
                ("Osasco", -23.5327, -46.7905),
                ("Presidente Altino", -23.5316, -46.7644),
                ("Palmeiras-Barra Funda", -23.5255, -46.6676),
                ("Julio Prestes", -23.5358, -46.6430)
            ]
        ),
        cptmLine(
            id: "L9",
            name: "Linha 9 - Esmeralda",
            colorHex: "01A9A7",
            stations: [
                ("Osasco", -23.5327, -46.7905),
                ("Ceasa", -23.5462, -46.7422),
                ("Pinheiros", -23.5675, -46.7018),
                ("Cidade Jardim", -23.5756, -46.6936),
                ("Vila Olimpia", -23.5952, -46.6892),
                ("Santo Amaro", -23.6540, -46.7142),
                ("Jurubatuba", -23.6810, -46.7082),
                ("Grajau", -23.7524, -46.6953)
            ]
        ),
        cptmLine(
            id: "L10",
            name: "Linha 10 - Turquesa",
            colorHex: "008B8B",
            stations: [
                ("Rio Grande da Serra", -23.7445, -46.4035),
                ("Maua", -23.6679, -46.4615),
                ("Santo Andre", -23.6561, -46.5307),
                ("Sao Caetano do Sul", -23.6187, -46.5564),
                ("Tamanduatei", -23.5938, -46.5899),
                ("Bras", -23.5434, -46.6166)
            ]
        ),
        cptmLine(
            id: "L11",
            name: "Linha 11 - Coral",
            colorHex: "F04E23",
            stations: [
                ("Luz", -23.5363, -46.6339),
                ("Bras", -23.5434, -46.6166),
                ("Tatuape", -23.5403, -46.5764),
                ("Corinthians-Itaquera", -23.5421, -46.4712),
                ("Guaianases", -23.5437, -46.4132),
                ("Suzano", -23.5448, -46.3097),
                ("Estudantes", -23.5223, -46.1904)
            ]
        ),
        cptmLine(
            id: "L12",
            name: "Linha 12 - Safira",
            colorHex: "083D8B",
            stations: [
                ("Bras", -23.5434, -46.6166),
                ("Tatuape", -23.5403, -46.5764),
                ("Engenheiro Goulart", -23.4970, -46.5308),
                ("Sao Miguel Paulista", -23.4938, -46.4430),
                ("Itaim Paulista", -23.5017, -46.3983),
                ("Calmon Viana", -23.5362, -46.3473)
            ]
        ),
        cptmLine(
            id: "L13",
            name: "Linha 13 - Jade",
            colorHex: "00B352",
            stations: [
                ("Palmeiras-Barra Funda", -23.5255, -46.6676),
                ("Luz", -23.5363, -46.6339),
                ("Bras", -23.5434, -46.6166),
                ("Engenheiro Goulart", -23.4970, -46.5308),
                ("Guarulhos-Cecap", -23.4762, -46.5250),
                ("Aeroporto-Guarulhos", -23.4354, -46.4730)
            ]
        )
    ]

    static let lines: [RailMapLine] = fallbackLines

    static let apiSources: [RailMapAPISource] = [
        RailMapAPISource(id: "L1", tripId: "METR\u{00D4} L1-0", system: .metro, name: "Linha 1 - Azul", colorHex: "0455A1"),
        RailMapAPISource(id: "L2", tripId: "METR\u{00D4} L2-0", system: .metro, name: "Linha 2 - Verde", colorHex: "007E5E"),
        RailMapAPISource(id: "L3", tripId: "METR\u{00D4} L3-0", system: .metro, name: "Linha 3 - Vermelha", colorHex: "EE372F"),
        RailMapAPISource(id: "L4", tripId: "METR\u{00D4} L4-0", system: .metro, name: "Linha 4 - Amarela", colorHex: "FFD700"),
        RailMapAPISource(id: "L5", tripId: "METR\u{00D4} L5-0", system: .metro, name: "Linha 5 - Lilas", colorHex: "9B3894"),
        RailMapAPISource(id: "L7", tripId: "CPTM L07-0", system: .cptm, name: "Linha 07 - Rubi", colorHex: "CA016B"),
        RailMapAPISource(id: "L8", tripId: "CPTM L08-0", system: .cptm, name: "Linha 08 - Diamante", colorHex: "97A098"),
        RailMapAPISource(id: "L9", tripId: "CPTM L09-0", system: .cptm, name: "Linha 09 - Esmeralda", colorHex: "01A9A7"),
        RailMapAPISource(id: "L10", tripId: "CPTM L10-0", system: .cptm, name: "Linha 10 - Turquesa", colorHex: "008B8B"),
        RailMapAPISource(id: "L11", tripId: "CPTM L11-0", system: .cptm, name: "Linha 11 - Coral", colorHex: "F04E23"),
        RailMapAPISource(id: "L12", tripId: "CPTM L12-0", system: .cptm, name: "Linha 12 - Safira", colorHex: "083D8B"),
        RailMapAPISource(id: "L13", tripId: "CPTM L13-0", system: .cptm, name: "Linha 13 - Jade", colorHex: "00B352")
    ]

    static func mergedLines(
        apiTripsByLineID: [String: TripStop],
        cachedLinesByID: [String: RailMapLine] = [:]
    ) -> [RailMapLine] {
        let apiLinesByID: [String: RailMapLine] = Dictionary(uniqueKeysWithValues: apiSources.compactMap { source in
            guard let trip = apiTripsByLineID[source.id] else { return nil }
            return (source.id, railLine(from: trip, source: source))
        })

        return fallbackLines.map { fallback in
            if let apiLine = apiLinesByID[fallback.id], !apiLine.stations.isEmpty {
                return apiLine
            }
            if let cachedLine = cachedLinesByID[fallback.id], !cachedLine.stations.isEmpty {
                return cachedLine
            }
            return fallback
        }
    }

    private static func metroLine(
        id: String,
        name: String,
        colorHex: String,
        stations: [(String, Double, Double)]
    ) -> RailMapLine {
        RailMapLine(
            id: id,
            name: name,
            system: .metro,
            colorHex: colorHex,
            stations: buildStations(system: .metro, lineId: id, colorHex: colorHex, stations: stations)
        )
    }

    private static func cptmLine(
        id: String,
        name: String,
        colorHex: String,
        stations: [(String, Double, Double)]
    ) -> RailMapLine {
        RailMapLine(
            id: id,
            name: name,
            system: .cptm,
            colorHex: colorHex,
            stations: buildStations(system: .cptm, lineId: id, colorHex: colorHex, stations: stations)
        )
    }

    private static func buildStations(
        system: RailSystem,
        lineId: String,
        colorHex: String,
        stations: [(String, Double, Double)]
    ) -> [RailMapStation] {
        stations.enumerated().map { index, station in
            RailMapStation(
                id: "\(lineId)-\(index)",
                stopId: syntheticRailStopId(lineId: lineId, index: index),
                name: station.0,
                coordinate: CLLocationCoordinate2D(latitude: station.1, longitude: station.2),
                system: system,
                colorHex: colorHex
            )
        }
    }

    private static func railLine(from tripStop: TripStop, source: RailMapAPISource) -> RailMapLine {
        let orderedStops = tripStop.stops
            .sorted { $0.stopSequence < $1.stopSequence }

        var seenStopIDs = Set<Int>()
        let stations: [RailMapStation] = orderedStops.compactMap { stop in
            guard seenStopIDs.insert(stop.stopId).inserted else { return nil }
            return RailMapStation(
                id: "\(source.id)-\(stop.stopId)",
                stopId: stop.stopId,
                name: stop.stopName,
                coordinate: stop.location.toCLLocationCoordinate2D(),
                system: source.system,
                colorHex: source.colorHex
            )
        }

        return RailMapLine(
            id: source.id,
            name: source.name,
            system: source.system,
            colorHex: source.colorHex,
            stations: stations
        )
    }
}

private func syntheticRailStopId(lineId: String, index: Int) -> Int {
    let lineNumber = Int(lineId.replacingOccurrences(of: "L", with: "")) ?? 0
    return 700_000_000 + (lineNumber * 10_000) + index
}

private func syntheticRailStopId(fromStationId stationId: String) -> Int {
    let parts = stationId.split(separator: "-", maxSplits: 1).map(String.init)
    if parts.count == 2, let index = Int(parts[1]) {
        if index >= 1_000 {
            // Older cache versions encoded API-backed stations as "Lx-<realStopId>".
            return index
        }
        return syntheticRailStopId(lineId: parts[0], index: index)
    }
    var hash = 0
    for scalar in stationId.unicodeScalars {
        hash = (hash &* 31 &+ Int(scalar.value)) & 0x7fffffff
    }
    return 799_000_000 + (hash % 999_999)
}

private extension RailSystem {
    var cacheValue: String {
        switch self {
        case .metro: return "metro"
        case .cptm: return "cptm"
        }
    }

    init?(cacheValue: String) {
        switch cacheValue {
        case "metro":
            self = .metro
        case "cptm":
            self = .cptm
        default:
            return nil
        }
    }
}
