import AppIntents
import Foundation

struct StopEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource(
                "intent.entity.stop.type",
                defaultValue: "Stop"
            )
        )
    }

    static var defaultQuery = StopEntityQuery()

    let id: Int
    let stopName: String
    let stopCode: String
    let routes: String?
    let latitude: Double
    let longitude: Double

    var displayRepresentation: DisplayRepresentation {
        let codeText = stopCode.isEmpty
            ? AppIntentL10n.format("intent.entity.stop.id_format", "\(id)")
            : AppIntentL10n.format("intent.entity.stop.code_format", stopCode)
        let routeText = routes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = [codeText, routeText].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " • ")

        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: stopName),
            subtitle: subtitle.isEmpty ? nil : LocalizedStringResource(stringLiteral: subtitle)
        )
    }

    var asDomainStop: Stop {
        Stop(
            stopId: id,
            stopName: stopName,
            location: Location(latitude: latitude, longitude: longitude),
            stopSequence: 0,
            routes: routes,
            stopCode: stopCode,
            wheelchairBoarding: 0
        )
    }
}

struct StopEntityQuery: EntityStringQuery {
    func entities(for identifiers: [StopEntity.ID]) async throws -> [StopEntity] {
        var resolved: [StopEntity] = []
        for identifier in identifiers {
            if let stop = try await resolveStop(by: identifier) {
                resolved.append(stop)
            }
        }
        return resolved
    }

    func entities(matching string: String) async throws -> [StopEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let stops = try await AppIntentTransitService.searchStops(query: trimmed, limit: 12)
        return stops.map(StopEntity.init)
    }

    func suggestedEntities() async throws -> [StopEntity] {
        let suggestions = ["Se", "Paulista", "Luz"]
        var entities: [StopEntity] = []

        for suggestion in suggestions {
            if let first = try await AppIntentTransitService.searchStops(query: suggestion, limit: 1).first {
                entities.append(StopEntity(first))
            }
        }

        return entities
    }

    private func resolveStop(by identifier: Int) async throws -> StopEntity? {
        let query = String(identifier)
        let results = try await AppIntentTransitService.searchStops(query: query, limit: 20)
        if let exact = results.first(where: { $0.stopId == identifier }) {
            return StopEntity(exact)
        }

        return StopEntity(
            id: identifier,
            stopName: AppIntentL10n.format("intent.entity.stop.fallback_name_format", "\(identifier)"),
            stopCode: "",
            routes: nil,
            latitude: -23.5505,
            longitude: -46.6333
        )
    }
}

private extension StopEntity {
    init(_ stop: Stop) {
        self.id = stop.stopId
        self.stopName = stop.stopName
        self.stopCode = stop.stopCode
        self.routes = stop.routes
        self.latitude = stop.location.latitude
        self.longitude = stop.location.longitude
    }
}
