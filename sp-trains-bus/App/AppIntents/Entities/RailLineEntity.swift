import AppIntents
import Foundation

struct RailLineEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource(
                "intent.entity.rail_line.type",
                defaultValue: "Rail Line"
            )
        )
    }

    static var defaultQuery = RailLineEntityQuery()

    let id: String
    let source: String
    let lineNumber: String
    let lineName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(source.uppercased()) L\(lineNumber) \(lineName)")
    }
}

struct RailLineEntityQuery: EntityStringQuery {
    func entities(for identifiers: [RailLineEntity.ID]) async throws -> [RailLineEntity] {
        let byID = Dictionary(uniqueKeysWithValues: RailLineEntity.catalog.map { ($0.id, $0) })
        return identifiers.compactMap { byID[$0] }
    }

    func entities(matching string: String) async throws -> [RailLineEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return RailLineEntity.catalog }

        let normalizedNeedle = normalize(trimmed)
        return RailLineEntity.catalog.filter { line in
            let haystacks = [
                line.id,
                line.source,
                line.lineNumber,
                line.lineName,
                "\(line.source) L\(line.lineNumber) \(line.lineName)"
            ]
            return haystacks.contains(where: { normalize($0).contains(normalizedNeedle) })
        }
    }

    func suggestedEntities() async throws -> [RailLineEntity] {
        RailLineEntity.catalog
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }
}

extension RailLineEntity {
    static let catalog: [RailLineEntity] = [
        RailLineEntity(id: "metro-1", source: "metro", lineNumber: "1", lineName: "Azul"),
        RailLineEntity(id: "metro-2", source: "metro", lineNumber: "2", lineName: "Verde"),
        RailLineEntity(id: "metro-3", source: "metro", lineNumber: "3", lineName: "Vermelha"),
        RailLineEntity(id: "metro-4", source: "metro", lineNumber: "4", lineName: "Amarela"),
        RailLineEntity(id: "metro-5", source: "metro", lineNumber: "5", lineName: "Lilas"),
        RailLineEntity(id: "metro-15", source: "metro", lineNumber: "15", lineName: "Prata"),
        RailLineEntity(id: "cptm-7", source: "cptm", lineNumber: "7", lineName: "Rubi"),
        RailLineEntity(id: "cptm-8", source: "cptm", lineNumber: "8", lineName: "Diamante"),
        RailLineEntity(id: "cptm-9", source: "cptm", lineNumber: "9", lineName: "Esmeralda"),
        RailLineEntity(id: "cptm-10", source: "cptm", lineNumber: "10", lineName: "Turquesa"),
        RailLineEntity(id: "cptm-11", source: "cptm", lineNumber: "11", lineName: "Coral"),
        RailLineEntity(id: "cptm-12", source: "cptm", lineNumber: "12", lineName: "Safira"),
        RailLineEntity(id: "cptm-13", source: "cptm", lineNumber: "13", lineName: "Jade")
    ]
}
