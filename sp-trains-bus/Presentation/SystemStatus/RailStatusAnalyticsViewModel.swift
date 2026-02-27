import Foundation
import Combine

enum RailStatusReportPeriod: Int, CaseIterable, Identifiable {
    case last7Days = 7
    case last14Days = 14
    case last30Days = 30

    var id: Int { rawValue }

    var label: String {
        "\(rawValue)d"
    }
}

enum RailStatusImpactLevel: String {
    case none
    case low
    case high

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "none":
            self = .none
        case "high":
            self = .high
        default:
            self = .low
        }
    }

    var score: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .high: return 2
        }
    }
}

struct RailStatusAnalyticsTotals {
    let sampleCount: Int
    let impactSampleCount: Int
    let impactRatio: Double
    let changeCount: Int
    let lineCount: Int

    static let empty = RailStatusAnalyticsTotals(
        sampleCount: 0,
        impactSampleCount: 0,
        impactRatio: 0,
        changeCount: 0,
        lineCount: 0
    )
}

struct RailStatusDailyPoint: Identifiable {
    let date: Date
    let sampleCount: Int
    let impactSampleCount: Int
    let impactRatio: Double
    let changeCount: Int
    let dominantStatus: String

    var id: Date { date }
}

struct RailStatusChangePoint: Identifiable {
    let date: Date
    let fromStatus: String
    let toStatus: String
    let impactLevel: RailStatusImpactLevel
    let impactScore: Int
    let impactingUser: Bool

    var id: String {
        "\(date.timeIntervalSince1970)-\(fromStatus)-\(toStatus)"
    }
}

struct RailStatusMixItem: Identifiable {
    let status: String
    let count: Int
    let ratio: Double
    let impactLevel: RailStatusImpactLevel
    let impactingUser: Bool

    var id: String { status }
}

struct RailStatusAnalyticsLine: Identifiable {
    let id: String
    let source: String
    let lineNumber: String
    let lineName: String
    let lineColorHex: String
    let sampleCount: Int
    let impactSampleCount: Int
    let impactRatio: Double
    let changeCount: Int
    let currentImpactLevel: RailStatusImpactLevel
    let currentStatus: String
    let dailyTimeline: [RailStatusDailyPoint]
    let statusMix: [RailStatusMixItem]
    let changes: [RailStatusChangePoint]

    var displayName: String {
        let sourceLabel = source.uppercased()
        if !lineNumber.isEmpty {
            let name = lineName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return "\(sourceLabel) L\(lineNumber) \(name)"
            }
            return "\(sourceLabel) L\(lineNumber)"
        }

        let name = lineName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? sourceLabel : "\(sourceLabel) \(name)"
    }

    var shortLabel: String {
        if !lineNumber.isEmpty {
            return "\(source.prefix(1).uppercased())\(lineNumber)"
        }
        return source.uppercased()
    }
}

final class RailStatusAnalyticsViewModel: ObservableObject {
    @Published var selectedPeriod: RailStatusReportPeriod = .last7Days
    @Published var selectedLineID: String?
    @Published private(set) var lines: [RailStatusAnalyticsLine] = []
    @Published private(set) var totals: RailStatusAnalyticsTotals = .empty
    @Published private(set) var generatedAtText: String?
    @Published private(set) var rangeText: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isAccessGranted: Bool = false

    private let apiClient: APIClient?
    private let analyticsService: AnalyticsServiceProtocol
    private let userDefaults: UserDefaults

    init(
        apiClient: APIClient?,
        analyticsService: AnalyticsServiceProtocol = NoOpAnalyticsService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.apiClient = apiClient
        self.analyticsService = analyticsService
        self.userDefaults = userDefaults
        self.isAccessGranted = StatusAnalyticsAccessGate.hasAccess(userDefaults: userDefaults)
    }

    var selectedLine: RailStatusAnalyticsLine? {
        guard let selectedLineID else { return lines.first }
        return lines.first(where: { $0.id == selectedLineID }) ?? lines.first
    }

    func trackScreenOpened() {
        analyticsService.trackScreen(name: "RailStatusAnalyticsView", className: "RailStatusAnalyticsView")
        analyticsService.trackEvent(
            name: "status_analytics_screen_opened",
            properties: ["is_access_granted": isAccessGranted ? "true" : "false"]
        )
    }

    func selectPeriod(_ period: RailStatusReportPeriod) {
        guard selectedPeriod != period else { return }
        selectedPeriod = period
        loadReport()
    }

    func selectLine(_ lineID: String) {
        guard selectedLineID != lineID else { return }
        selectedLineID = lineID
        analyticsService.trackEvent(
            name: "status_analytics_line_selected",
            properties: ["line_id": lineID]
        )
    }

    func loadReport() {
        isAccessGranted = StatusAnalyticsAccessGate.hasAccess(userDefaults: userDefaults)
        guard isAccessGranted else {
            lines = []
            totals = .empty
            generatedAtText = nil
            rangeText = nil
            errorMessage = nil
            isLoading = false
            analyticsService.trackEvent(name: "status_analytics_load_blocked_locked")
            return
        }

        isLoading = true
        errorMessage = nil
        let period = selectedPeriod

        analyticsService.trackEvent(
            name: "status_analytics_load_requested",
            properties: ["period_days": "\(period.rawValue)"]
        )

        guard let apiClient else {
            lines = []
            totals = .empty
            generatedAtText = nil
            rangeText = nil
            errorMessage = "Analytics indisponível sem API remota."
            isLoading = false
            return
        }

        Task {
            do {
                let response: RailStatusReportResponseDTO = try await apiClient.request(
                    endpoint: TransitAPIEndpoint.railStatusReport(periodDays: period.rawValue)
                )

                let mappedLines = mapLines(response.lines)
                let mappedTotals = RailStatusAnalyticsTotals(
                    sampleCount: response.totals.sampleCount,
                    impactSampleCount: response.totals.impactSampleCount,
                    impactRatio: response.totals.impactRatio,
                    changeCount: response.totals.changeCount,
                    lineCount: response.totals.lineCount
                )
                let generatedText = displayTimestamp(response.generatedAt)
                let rangeText = displayRange(startAt: response.startAt, endAt: response.endAt)

                await MainActor.run {
                    self.lines = mappedLines
                    self.totals = mappedTotals
                    self.generatedAtText = generatedText
                    self.rangeText = rangeText
                    if let selectedLineID = self.selectedLineID,
                       mappedLines.contains(where: { $0.id == selectedLineID }) {
                        self.selectedLineID = selectedLineID
                    } else {
                        self.selectedLineID = mappedLines.first?.id
                    }
                    self.errorMessage = nil
                    self.isLoading = false
                    self.analyticsService.trackEvent(
                        name: "status_analytics_load_succeeded",
                        properties: [
                            "line_count": "\(mappedLines.count)",
                            "sample_count": "\(mappedTotals.sampleCount)"
                        ]
                    )
                }
            } catch {
                await MainActor.run {
                    self.lines = []
                    self.totals = .empty
                    self.generatedAtText = nil
                    self.rangeText = nil
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.analyticsService.trackEvent(
                        name: "status_analytics_load_failed",
                        properties: ["error": error.localizedDescription]
                    )
                }
            }
        }
    }

    private func mapLines(_ dtos: [RailStatusReportLineDTO]) -> [RailStatusAnalyticsLine] {
        dtos.map { dto in
            let currentLevel = RailStatusImpactLevel(rawValue: dto.currentStatus?.impactLevel ?? "low")

            let daily = dto.dailyTimeline.compactMap { point -> RailStatusDailyPoint? in
                guard let date = parseDate(point.date) else { return nil }
                return RailStatusDailyPoint(
                    date: date,
                    sampleCount: point.sampleCount,
                    impactSampleCount: point.impactSampleCount,
                    impactRatio: point.impactRatio,
                    changeCount: point.changeCount,
                    dominantStatus: point.dominantStatus
                )
            }

            let changes = dto.statusChanges.compactMap { point -> RailStatusChangePoint? in
                guard let date = parseDateTime(point.at) else { return nil }
                let impactLevel = RailStatusImpactLevel(rawValue: point.impactLevel)
                return RailStatusChangePoint(
                    date: date,
                    fromStatus: point.fromStatus,
                    toStatus: point.toStatus,
                    impactLevel: impactLevel,
                    impactScore: point.impactScore,
                    impactingUser: point.impactingUser
                )
            }

            let mix = dto.statusDistribution.map { item in
                RailStatusMixItem(
                    status: item.status,
                    count: item.count,
                    ratio: item.ratio,
                    impactLevel: RailStatusImpactLevel(rawValue: item.impactLevel),
                    impactingUser: item.impactingUser
                )
            }

            return RailStatusAnalyticsLine(
                id: dto.lineId,
                source: dto.source,
                lineNumber: dto.lineNumber,
                lineName: dto.lineName,
                lineColorHex: dto.lineColor,
                sampleCount: dto.sampleCount,
                impactSampleCount: dto.impactSampleCount,
                impactRatio: dto.impactRatio,
                changeCount: dto.changeCount,
                currentImpactLevel: currentLevel,
                currentStatus: dto.currentStatus?.status ?? "",
                dailyTimeline: daily,
                statusMix: mix,
                changes: changes
            )
        }
        .sorted { lhs, rhs in
            if lhs.impactRatio == rhs.impactRatio {
                if lhs.changeCount == rhs.changeCount {
                    return lhs.displayName < rhs.displayName
                }
                return lhs.changeCount > rhs.changeCount
            }
            return lhs.impactRatio > rhs.impactRatio
        }
    }

    private func parseDateTime(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: raw)
    }

    private func parseDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    private func displayTimestamp(_ raw: String?) -> String? {
        guard let raw else { return nil }
        guard let date = parseDateTime(raw) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }

    private func displayRange(startAt: String, endAt: String) -> String? {
        guard let startDate = parseDateTime(startAt),
              let endDate = parseDateTime(endAt) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd/MM"

        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}
