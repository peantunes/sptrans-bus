import Foundation
import Combine

enum RailStatusSeverity: Int {
    case normal = 0
    case warning = 1
    case alert = 2
}

struct RailLineStatusItem: Identifiable {
    let id: String
    let source: String
    let lineNumber: String
    let lineName: String
    let status: String
    let statusDetail: String
    let statusColorHex: String
    let lineColorHex: String
    let sourceUpdatedAt: String?
    let severity: RailStatusSeverity

    var displayTitle: String {
        let trimmedName = lineName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }
        let trimmedNumber = lineNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNumber.isEmpty {
            return "Linha \(trimmedNumber)"
        }
        return source.uppercased()
    }

    var badgeText: String {
        let trimmedNumber = lineNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNumber.isEmpty {
            return "L\(trimmedNumber)"
        }
        return source.uppercased()
    }

    var detailText: String {
        let trimmed = statusDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if let sourceUpdatedAt, !sourceUpdatedAt.isEmpty {
            return "Atualizado em \(sourceUpdatedAt)"
        }
        return source.uppercased()
    }
}

class SystemStatusViewModel: ObservableObject {
    @Published var metroLines: [MetroLine] = []
    @Published var metroLineStatuses: [RailLineStatusItem] = []
    @Published var cptmLineStatuses: [RailLineStatusItem] = []
    @Published var overallStatus: String = "Loading..."
    @Published var overallSeverity: RailStatusSeverity = .warning
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient?
    private let getMetroStatusUseCase: GetMetroStatusUseCase?

    init(apiClient: APIClient, fallbackUseCase: GetMetroStatusUseCase = GetMetroStatusUseCase()) {
        self.apiClient = apiClient
        self.getMetroStatusUseCase = fallbackUseCase
    }

    init(getMetroStatusUseCase: GetMetroStatusUseCase) {
        self.apiClient = nil
        self.getMetroStatusUseCase = getMetroStatusUseCase
    }

    func loadMetroStatus(forceRefresh: Bool = false) {
        isLoading = true
        errorMessage = nil

        guard let apiClient else {
            loadFallbackMetroStatus()
            return
        }

        Task {
            do {
                let response: RailStatusResponseDTO = try await apiClient.request(
                    endpoint: TransitAPIEndpoint.metroCPTM(refresh: forceRefresh)
                )

                let metroItems = mapLines(response.metro.lines, source: "metro")
                let cptmItems = mapLines(response.cptm.lines, source: "cptm")

                await MainActor.run {
                    self.applyStatusData(metroItems: metroItems, cptmItems: cptmItems)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.metroLineStatuses = []
                    self.cptmLineStatuses = []
                    self.metroLines = []
                    self.overallStatus = "Falha ao carregar status"
                    self.overallSeverity = .alert
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func loadFallbackMetroStatus() {
        guard let getMetroStatusUseCase else {
            overallStatus = "No data available"
            overallSeverity = .warning
            isLoading = false
            return
        }

        let fallback = getMetroStatusUseCase.execute()
        metroLines = fallback
        metroLineStatuses = fallback.map {
            RailLineStatusItem(
                id: "metro-\(normalizedLineNumber($0.line))-\($0.name)",
                source: "metro",
                lineNumber: normalizedLineNumber($0.line),
                lineName: $0.name,
                status: "Operação Normal",
                statusDetail: "Sem alertas no momento",
                statusColorHex: "00E000",
                lineColorHex: $0.colorHex,
                sourceUpdatedAt: nil,
                severity: .normal
            )
        }
        cptmLineStatuses = []
        updateOverallStatus()
        isLoading = false
    }

    private func applyStatusData(metroItems: [RailLineStatusItem], cptmItems: [RailLineStatusItem]) {
        metroLineStatuses = metroItems
        cptmLineStatuses = cptmItems

        metroLines = metroItems.map {
            MetroLine(line: $0.badgeText, name: $0.displayTitle, colorHex: $0.lineColorHex)
        }

        updateOverallStatus()
    }

    private func mapLines(_ lines: [RailLineStatusDTO], source: String) -> [RailLineStatusItem] {
        lines
            .enumerated()
            .map { index, dto in
                var lineNumber = normalizedLineNumber(dto.lineNumber)
                var lineName = dto.lineName.trimmingCharacters(in: .whitespacesAndNewlines)

                if source.lowercased() == "cptm" {
                    let fallback = cptmFallback(for: index)
                    if lineNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lineNumber = fallback.number
                    }
                    if lineName.isEmpty {
                        lineName = fallback.name
                    }
                }

                let status = dto.status.trimmingCharacters(in: .whitespacesAndNewlines)
                let severity = statusSeverity(status: status)
                let statusColorHex = normalizedHex(dto.statusColor) ?? fallbackStatusColorHex(status: status, severity: severity)
                let identifier = "\(source)-\(lineNumber.isEmpty ? "idx\(index)" : lineNumber)-\(lineName.isEmpty ? "idx\(index)" : lineName)"

                return RailLineStatusItem(
                    id: identifier,
                    source: source,
                    lineNumber: lineNumber,
                    lineName: lineName,
                    status: status.isEmpty ? "Status indisponível" : status,
                    statusDetail: dto.statusDetail,
                    statusColorHex: statusColorHex,
                    lineColorHex: lineColorHex(source: source, lineNumber: lineNumber),
                    sourceUpdatedAt: dto.sourceUpdatedAt,
                    severity: severity
                )
            }
            .sorted { lhs, rhs in
                let leftOrder = Int(lhs.lineNumber) ?? Int.max
                let rightOrder = Int(rhs.lineNumber) ?? Int.max
                if leftOrder == rightOrder {
                    return lhs.displayTitle < rhs.displayTitle
                }
                return leftOrder < rightOrder
            }
    }

    private func updateOverallStatus() {
        let allLines = metroLineStatuses + cptmLineStatuses
        guard !allLines.isEmpty else {
            overallStatus = "No data available"
            overallSeverity = .warning
            return
        }

        let highestSeverity = allLines.map(\.severity).max(by: { $0.rawValue < $1.rawValue }) ?? .warning
        overallSeverity = highestSeverity

        switch highestSeverity {
        case .normal:
            overallStatus = "Operação Normal"
        case .warning:
            overallStatus = "Operação com alertas"
        case .alert:
            overallStatus = "Serviço com interrupções"
        }
    }

    private func statusSeverity(status: String) -> RailStatusSeverity {
        let normalized = status
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
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

    private func normalizedHex(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("#") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private func fallbackStatusColorHex(status: String, severity: RailStatusSeverity) -> String {
        let normalized = status
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        // Keep partial/abnormal-but-running services as orange, even though they are "warning".
        let partialTerms = [
            "parcial", "normalizacao", "interferencia", "manutencao"
        ]
        if partialTerms.contains(where: { normalized.contains($0) }) {
            return "FF8C00"
        }

        let reducedTerms = [
            "velocidade reduzida", "atencao", "lento", "lentidao"
        ]
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

    private func normalizedLineNumber(_ raw: String) -> String {
        let digitsOnly = raw.filter(\.isNumber)
        return digitsOnly.isEmpty ? raw : digitsOnly
    }

    private func cptmFallback(for index: Int) -> (number: String, name: String) {
        let fallbacks: [(String, String)] = [
            ("10", "Turquesa"),
            ("11", "Coral"),
            ("12", "Safira"),
            ("13", "Jade")
        ]

        guard fallbacks.indices.contains(index) else {
            return ("", "")
        }
        return fallbacks[index]
    }
}
