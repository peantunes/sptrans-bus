import Foundation

struct Stop: Codable, Identifiable {
    enum TransportType {
        case bus
        case metro
        case train
    }
    var id: Int {
        stopId
    }
    let stopId: Int
    let stopName: String
    let location: Location
    let stopSequence: Int
    let routes: String?
    let stopCode: String
    let wheelchairBoarding: Int
    
    var transportType: TransportType {
        if routes?.contains("METRÔ") == true {
            return .metro
        } else if routes?.contains("CPTM") == true {
            return .train
        }
        return .bus
    }

    var isRailOnlyService: Bool {
        let tokens = routeTokens
        guard !tokens.isEmpty else { return false }

        let railTokens = tokens.filter { token in
            token.contains("METRO") || token.contains("CPTM")
        }
        return !railTokens.isEmpty && railTokens.count == tokens.count
    }

    private var routeTokens: [String] {
        guard let routes else { return [] }
        return routes
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .components(separatedBy: CharacterSet(charactersIn: ",;/|"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
