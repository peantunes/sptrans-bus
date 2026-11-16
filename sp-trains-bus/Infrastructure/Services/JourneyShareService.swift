import Foundation

/// Shared journey links: https://sptrans.lolados.app/j/<token> (server: inc/JourneyShare.class.php).
/// The app sends references only (trip, stops, time); the server rebuilds and stores the journey,
/// so a link can never be edited into something else. Origin and destination are never sent.
enum JourneyShareLink {
    static let host = "sptrans.lolados.app"

    /// The token of a shared journey link, or nil for any other URL.
    static func token(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "https", url.host?.lowercased() == host else { return nil }
        let parts = url.path.split(separator: "/")
        guard parts.count == 2, parts[0] == "j" else { return nil }
        let token = String(parts[1])
        guard token.count == 12, token.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return token
    }
}

struct ShareJourneyRequestDTO: Encodable {
    struct Leg: Encodable {
        let tripId: String
        let from: String
        let to: String
        let departure: String
    }

    let date: String
    let legs: [Leg]
}

struct ShareJourneyResponseDTO: Decodable {
    let token: String
    let url: String
}

struct SharedJourneyDTO: Decodable {
    let token: String
    let url: String
    let from: String
    let to: String
    let state: String
    let departsAt: TimeInterval?
    let journey: PlanAlternativeDTO
}

enum JourneyShareError: LocalizedError, Equatable {
    case notShareable
    case notFound
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notShareable: return NSLocalizedString("This journey can't be shared.", comment: "")
        case .notFound: return NSLocalizedString("This shared journey is no longer available.", comment: "")
        case .unavailable: return NSLocalizedString("Sharing is unavailable right now. Try again later.", comment: "")
        }
    }
}

/// A shared journey ready for the detail screen.
struct SharedJourney {
    let token: String
    let url: URL
    let from: String
    let to: String
    let state: String
    let departure: Date?
    let alternative: TripPlanAlternative
}

final class JourneyShareService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Builds the request for a journey: every vehicle leg needs its trip, stops and departure time.
    static func request(for alternative: TripPlanAlternative, departureDate: Date?) -> ShareJourneyRequestDTO? {
        let legs = alternative.vehicleLegs
        guard !legs.isEmpty, alternative.type != .walk else { return nil }
        var refs: [ShareJourneyRequestDTO.Leg] = []
        for leg in legs {
            guard let tripId = leg.tripId, !tripId.isEmpty,
                  let from = leg.originStopId, let to = leg.destinationStopId,
                  let departure = leg.departureTime, !departure.isEmpty else { return nil }
            refs.append(.init(tripId: tripId, from: String(from), to: String(to), departure: departure))
        }
        return ShareJourneyRequestDTO(date: serviceDay(departureDate ?? Date()), legs: refs)
    }

    func create(alternative: TripPlanAlternative, departureDate: Date?) async throws -> URL {
        guard let request = Self.request(for: alternative, departureDate: departureDate) else {
            throw JourneyShareError.notShareable
        }
        do {
            let response: ShareJourneyResponseDTO = try await apiClient.request(endpoint: TransitAPIEndpoint.shareJourney(payload: request))
            guard let url = URL(string: response.url) else { throw JourneyShareError.unavailable }
            return url
        } catch let error as JourneyShareError {
            throw error
        } catch {
            throw JourneyShareError.unavailable
        }
    }

    func load(token: String) async throws -> SharedJourney {
        let dto: SharedJourneyDTO
        do {
            dto = try await apiClient.request(endpoint: TransitAPIEndpoint.sharedJourney(token: token))
        } catch APIError.invalidResponse {
            throw JourneyShareError.notFound
        } catch {
            throw JourneyShareError.unavailable
        }
        return SharedJourney(
            token: dto.token,
            url: URL(string: dto.url) ?? URL(string: "https://\(JourneyShareLink.host)/j/\(dto.token)")!,
            from: dto.from,
            to: dto.to,
            state: dto.state,
            departure: dto.departsAt.map { Date(timeIntervalSince1970: $0) },
            alternative: dto.journey.toDomain()
        )
    }

    /// São Paulo calendar day of the departure, "yyyy-MM-dd".
    static func serviceDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
