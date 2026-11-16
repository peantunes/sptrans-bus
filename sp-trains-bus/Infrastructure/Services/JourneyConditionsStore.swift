import Foundation
import Combine

/// Shares the existing cached rail-status API between journey results and detail.
@MainActor
final class JourneyConditionsStore: ObservableObject {
    @Published private(set) var railLines: [JourneyRailLineStatus] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var failed = false
    private var lastRequestAt: Date?
    private let apiClient: APIClient

    init(apiClient: APIClient) { self.apiClient = apiClient }

    func refresh() async {
        guard !isLoading else { return }
        if let lastRequestAt, Date().timeIntervalSince(lastRequestAt) < 60 { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        do {
            let response: RailStatusResponseDTO = try await apiClient.request(endpoint: TransitAPIEndpoint.metroCPTM(refresh: false))
            railLines = Self.map(response.metro, source: "metro") + Self.map(response.cptm, source: "cptm")
            failed = false
            lastRequestAt = Date()
        } catch {
            // Retain last known alerts, visibly marked as stale, instead of claiming normal operation.
            failed = true
            lastRequestAt = nil
        }
    }

    func alerts(for alternative: TripPlanAlternative) -> [JourneyRailLineStatus] {
        railLines.filter { line in line.isDisrupted && alternative.vehicleLegs.contains(where: line.matches) }
    }

    func statusUnavailable(for alternative: TripPlanAlternative) -> Bool {
        let railLegs = alternative.vehicleLegs.filter { $0.railSource != nil }
        guard !railLegs.isEmpty else { return false }
        return failed || (hasLoaded && railLegs.contains { leg in
            !railLines.contains { $0.matches(leg) && $0.hasKnownStatus && !$0.isStale() }
        })
    }

    private static func map(_ response: RailSourceStatusDTO, source: String) -> [JourneyRailLineStatus] {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let fetchedAt = response.lastFetchedAt.flatMap { parser.date(from: $0) }
        return response.lines.map {
            JourneyRailLineStatus(source: source, lineNumber: $0.lineNumber, lineName: $0.lineName,
                status: $0.status, detail: $0.statusDetail,
                updatedAt: $0.sourceUpdatedAt ?? response.lastSourceUpdatedAt ?? response.lastFetchedAt,
                fetchedAt: fetchedAt, available: response.available)
        }
    }
}
