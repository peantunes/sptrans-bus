import AppIntents
import Foundation

struct CheckRailStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.rail.title"
    static var description = IntentDescription("intent.rail.description")

    @Parameter(title: "intent.rail.parameter.line")
    var line: RailLineEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("intent.rail.summary")
    }

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let response = try await AppIntentTransitService.getRailStatus()
        let snapshots = buildSnapshots(from: response)

        if let line {
            let message = singleLineMessage(for: line, in: snapshots)
            return .result(value: message, dialog: IntentDialog(stringLiteral: message))
        }

        let message = networkMessage(from: snapshots)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }

    private func singleLineMessage(for line: RailLineEntity, in snapshots: [RailIntentLineSnapshot]) -> String {
        let lineDisplayName = AppIntentL10n.format(
            "intent.rail.line_display_format",
            line.source.uppercased(),
            line.lineNumber,
            line.lineName
        )

        guard let target = snapshots.first(where: {
            $0.source == line.source && ($0.lineNumber == line.lineNumber || normalize($0.lineName) == normalize(line.lineName))
        }) else {
            return AppIntentL10n.format("intent.rail.line_not_found", lineDisplayName)
        }

        let impact = target.impactingUser
            ? AppIntentL10n.text("intent.rail.impact.high")
            : AppIntentL10n.text("intent.rail.impact.low")

        if target.statusDetail.isEmpty {
            return AppIntentL10n.format(
                "intent.rail.line_status_without_detail",
                lineDisplayName,
                target.status,
                impact
            )
        }

        return AppIntentL10n.format(
            "intent.rail.line_status_with_detail",
            lineDisplayName,
            target.status,
            impact,
            target.statusDetail
        )
    }

    private func networkMessage(from snapshots: [RailIntentLineSnapshot]) -> String {
        guard !snapshots.isEmpty else {
            return AppIntentL10n.text("intent.rail.network_unavailable")
        }

        let alertCount = snapshots.filter { $0.severity == .alert }.count
        let warningCount = snapshots.filter { $0.severity == .warning }.count

        if alertCount == 0 && warningCount == 0 {
            return AppIntentL10n.text("intent.rail.network_normal")
        }

        if let topIssue = snapshots.max(by: { $0.severity.rawValue < $1.severity.rawValue }) {
            let issueCount = alertCount + warningCount
            return AppIntentL10n.format(
                "intent.rail.network_issues_format",
                issueCount,
                topIssue.source.uppercased(),
                topIssue.lineNumber,
                topIssue.lineName,
                topIssue.status
            )
        }

        return AppIntentL10n.text("intent.rail.network_active_alerts")
    }

    private func buildSnapshots(from response: RailStatusResponseDTO) -> [RailIntentLineSnapshot] {
        let metroLines = response.metro.lines.map { RailIntentLineSnapshot(source: "metro", line: $0) }
        let cptmLines = response.cptm.lines.map { RailIntentLineSnapshot(source: "cptm", line: $0) }
        return metroLines + cptmLines
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }
}

private struct RailIntentLineSnapshot {
    let source: String
    let lineNumber: String
    let lineName: String
    let status: String
    let statusDetail: String
    let severity: RailIntentSeverity

    init(source: String, line: RailLineStatusDTO) {
        self.source = source
        self.lineNumber = line.lineNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lineName = line.lineName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.status = line.status.trimmingCharacters(in: .whitespacesAndNewlines)
        self.statusDetail = line.statusDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        self.severity = RailIntentSeverity.from(status: line.status)
    }

    var impactingUser: Bool {
        severity != .normal
    }
}

private enum RailIntentSeverity: Int {
    case normal = 0
    case warning = 1
    case alert = 2

    static func from(status rawStatus: String) -> RailIntentSeverity {
        let normalized = rawStatus
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if normalized.contains("normal") {
            return .normal
        }

        let alertTerms = [
            "interrompid", "paralisad", "suspens", "encerrad",
            "sem operacao", "inoperante", "falha grave", "indisponivel"
        ]
        if alertTerms.contains(where: { normalized.contains($0) }) {
            return .alert
        }

        return .warning
    }
}
