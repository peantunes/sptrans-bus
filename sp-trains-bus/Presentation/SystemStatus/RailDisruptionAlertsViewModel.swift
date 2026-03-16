import Foundation
import Combine
import UserNotifications

struct RailDisruptionAlertLine: Identifiable {
    let id: String
    let source: String
    let lineNumber: String
    let lineName: String

    var displayName: String {
        let sourceLabel = source.uppercased()
        if !lineNumber.isEmpty {
            return "\(sourceLabel) L\(lineNumber) \(lineName)"
        }
        return "\(sourceLabel) \(lineName)"
    }
}

final class RailDisruptionAlertsViewModel: ObservableObject {
    @Published private(set) var lines: [RailDisruptionAlertLine] = []
    @Published private(set) var selectedLineIDs: Set<String> = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var isAccessGranted: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var shouldShowSettingsHint: Bool = false

    private let apiClient: APIClient?
    private let pushNotificationManager: PushNotificationManager
    private let analyticsService: AnalyticsServiceProtocol
    private let userDefaults: UserDefaults
    private let localeIdentifier: String
    private let timezoneIdentifier: String

    init(
        apiClient: APIClient?,
        lines: [RailLineStatusItem],
        pushNotificationManager: PushNotificationManager = .shared,
        analyticsService: AnalyticsServiceProtocol = NoOpAnalyticsService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.apiClient = apiClient
        self.pushNotificationManager = pushNotificationManager
        self.analyticsService = analyticsService
        self.userDefaults = userDefaults
        self.localeIdentifier = Locale.current.identifier
        self.timezoneIdentifier = TimeZone.current.identifier
        self.lines = Self.buildLines(from: lines)
        self.isAccessGranted = PremiumAccessGate.hasDisruptionAlertsAccess(userDefaults: userDefaults)
    }

    var metroLines: [RailDisruptionAlertLine] {
        lines.filter { $0.source == "metro" }
    }

    var cptmLines: [RailDisruptionAlertLine] {
        lines.filter { $0.source == "cptm" }
    }

    var selectedCount: Int {
        selectedLineIDs.count
    }

    var hasSelectableLines: Bool {
        !lines.isEmpty
    }

    var areAllLinesSelected: Bool {
        hasSelectableLines && selectedLineIDs.count == lines.count
    }

    func trackScreenOpened() {
        analyticsService.trackScreen(name: "RailDisruptionAlertsView", className: "RailDisruptionAlertsView")
        analyticsService.trackEvent(
            name: "rail_disruption_alerts_screen_opened",
            properties: ["is_access_granted": isAccessGranted ? "true" : "false"]
        )
    }

    func refreshAccessStatus() {
        isAccessGranted = PremiumAccessGate.hasDisruptionAlertsAccess(userDefaults: userDefaults)
    }

    func isSelected(_ line: RailDisruptionAlertLine) -> Bool {
        selectedLineIDs.contains(line.id)
    }

    func toggle(_ line: RailDisruptionAlertLine) {
        if selectedLineIDs.contains(line.id) {
            selectedLineIDs.remove(line.id)
        } else {
            selectedLineIDs.insert(line.id)
        }
    }

    func toggleSelectAll() {
        guard hasSelectableLines else { return }
        if areAllLinesSelected {
            selectedLineIDs.removeAll()
        } else {
            selectedLineIDs = Set(lines.map(\.id))
        }
    }

    func loadExistingSubscriptions() {
        refreshAccessStatus()
        guard isAccessGranted else {
            isLoading = false
            isSaving = false
            shouldShowSettingsHint = false
            errorMessage = nil
            successMessage = nil
            analyticsService.trackEvent(name: "rail_disruption_alerts_load_blocked_locked")
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        guard let apiClient else {
            isLoading = false
            errorMessage = NSLocalizedString("status.alerts.error.api_unavailable", comment: "")
            return
        }

        let installationID = pushNotificationManager.installationId
        Task {
            do {
                let response: RailAlertSubscriptionStateEnvelopeDTO = try await apiClient.request(
                    endpoint: TransitAPIEndpoint.railAlertSubscriptionsState(installationId: installationID)
                )
                let availableIDs = Set(lines.map(\.id))
                let selectedFromServer = Set(response.state.subscriptions.map(\.lineId)).intersection(availableIDs)
                let authStatus = parseAuthorizationStatus(response.state.authorizationStatus)

                await MainActor.run {
                    self.selectedLineIDs = selectedFromServer
                    self.shouldShowSettingsHint = authStatus == .denied
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func saveSubscriptions() {
        refreshAccessStatus()
        guard isAccessGranted else {
            isSaving = false
            shouldShowSettingsHint = false
            errorMessage = NSLocalizedString("status.alerts.locked.message", comment: "")
            analyticsService.trackEvent(name: "rail_disruption_alerts_save_blocked_locked")
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil
        shouldShowSettingsHint = false

        guard let apiClient else {
            isSaving = false
            errorMessage = NSLocalizedString("status.alerts.error.api_unavailable", comment: "")
            return
        }

        Task {
            let selectedLines = self.lines.filter { self.selectedLineIDs.contains($0.id) }
            let hasSelections = !selectedLines.isEmpty
            var authStatus = await pushNotificationManager.currentAuthorizationStatus()

            if hasSelections {
                authStatus = await pushNotificationManager.requestAuthorizationIfNeeded()
                if authStatus == .denied {
                    await MainActor.run {
                        self.shouldShowSettingsHint = true
                        self.isSaving = false
                        self.errorMessage = NSLocalizedString("status.alerts.error.notifications_denied", comment: "")
                    }
                    return
                }
            }

            if authStatus == .authorized || authStatus == .provisional || authStatus == .ephemeral {
                pushNotificationManager.registerForRemoteNotifications()
            }

            let payload = RailAlertSubscriptionUpdateRequestDTO(
                installationId: pushNotificationManager.installationId,
                action: "set",
                platform: "ios",
                apnsToken: pushNotificationManager.apnsToken,
                notificationsEnabled: authStatus == .authorized || authStatus == .provisional || authStatus == .ephemeral,
                authorizationStatus: authorizationStatusString(authStatus),
                locale: localeIdentifier,
                timezone: timezoneIdentifier,
                appVersion: appVersion(),
                buildVersion: buildVersion(),
                lines: selectedLines.map { line in
                    RailAlertSubscriptionLineRequestDTO(
                        lineId: line.id,
                        source: line.source,
                        lineNumber: line.lineNumber,
                        lineName: line.lineName
                    )
                }
            )

            do {
                let response: RailAlertSubscriptionUpdateResponseDTO = try await apiClient.request(
                    endpoint: TransitAPIEndpoint.railAlertSubscriptionsUpdate(payload: payload)
                )
                let availableIDs = Set(lines.map(\.id))
                let selectedFromServer = Set(response.state.subscriptions.map(\.lineId)).intersection(availableIDs)

                await MainActor.run {
                    self.selectedLineIDs = selectedFromServer
                    self.isSaving = false
                    self.successMessage = NSLocalizedString("status.alerts.saved", comment: "")
                    self.analyticsService.trackEvent(
                        name: "rail_disruption_alerts_saved",
                        properties: ["subscriptions_count": "\(selectedFromServer.count)"]
                    )
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }

    private func appVersion() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }

    private func buildVersion() -> String {
        (Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String) ?? "1"
    }

    private func parseAuthorizationStatus(_ raw: String?) -> UNAuthorizationStatus {
        guard let raw else { return .notDetermined }
        switch raw.lowercased() {
        case "authorized":
            return .authorized
        case "provisional":
            return .provisional
        case "ephemeral":
            return .ephemeral
        case "denied":
            return .denied
        default:
            return .notDetermined
        }
    }

    private func authorizationStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        case .provisional:
            return "provisional"
        case .ephemeral:
            return "ephemeral"
        @unknown default:
            return "unknown"
        }
    }

    private static func buildLines(from items: [RailLineStatusItem]) -> [RailDisruptionAlertLine] {
        var map: [String: RailDisruptionAlertLine] = [:]

        for item in items {
            let source = item.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard source == "metro" || source == "cptm" else { continue }

            let lineNumber = item.lineNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let lineName = item.lineName.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = lineName.isEmpty ? item.displayTitle : lineName
            let lineID = makeLineID(source: source, lineNumber: lineNumber, lineName: normalizedName)

            map[lineID] = RailDisruptionAlertLine(
                id: lineID,
                source: source,
                lineNumber: lineNumber,
                lineName: normalizedName
            )
        }

        return Array(map.values).sorted { lhs, rhs in
            if lhs.source != rhs.source {
                return lhs.source < rhs.source
            }
            let lhsNum = Int(lhs.lineNumber.filter(\.isNumber)) ?? Int.max
            let rhsNum = Int(rhs.lineNumber.filter(\.isNumber)) ?? Int.max
            if lhsNum == rhsNum {
                return lhs.lineName < rhs.lineName
            }
            return lhsNum < rhsNum
        }
    }

    private static func makeLineID(source: String, lineNumber: String, lineName: String) -> String {
        let normalizedNumber = lineNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedNumber.isEmpty {
            return "\(source)-\(normalizedNumber)"
        }
        let normalizedName = lineName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "\(source)-\(normalizedName)"
    }
}
