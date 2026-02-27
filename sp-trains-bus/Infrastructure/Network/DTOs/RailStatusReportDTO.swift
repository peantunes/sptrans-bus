import Foundation

struct RailStatusReportResponseDTO: Decodable {
    let generatedAt: String
    let periodDays: Int
    let startAt: String
    let endAt: String
    let filters: RailStatusReportFiltersDTO
    let totals: RailStatusReportTotalsDTO
    let statusCatalog: [RailStatusCatalogItemDTO]
    let lines: [RailStatusReportLineDTO]
}

struct RailStatusReportFiltersDTO: Decodable {
    let source: String?
    let lineNumber: String?
}

struct RailStatusReportTotalsDTO: Decodable {
    let sampleCount: Int
    let impactSampleCount: Int
    let impactRatio: Double
    let changeCount: Int
    let lineCount: Int
}

struct RailStatusCatalogItemDTO: Decodable {
    let status: String
    let count: Int
    let impactingUser: Bool
    let impactLevel: String
    let impactScore: Int
}

struct RailStatusReportLineDTO: Decodable {
    let lineId: String
    let source: String
    let lineNumber: String
    let lineName: String
    let lineColor: String
    let sampleCount: Int
    let impactSampleCount: Int
    let impactRatio: Double
    let changeCount: Int
    let currentStatus: RailStatusCurrentStatusDTO?
    let statusDistribution: [RailStatusDistributionDTO]
    let dailyTimeline: [RailStatusDailyTimelineDTO]
    let statusChanges: [RailStatusChangeDTO]
}

struct RailStatusCurrentStatusDTO: Decodable {
    let status: String
    let statusDetail: String
    let statusColor: String
    let at: String
    let impactingUser: Bool
    let impactLevel: String
    let impactScore: Int
}

struct RailStatusDistributionDTO: Decodable {
    let status: String
    let count: Int
    let impactingUser: Bool
    let impactLevel: String
    let impactScore: Int
    let ratio: Double
}

struct RailStatusDailyTimelineDTO: Decodable {
    let date: String
    let sampleCount: Int
    let impactSampleCount: Int
    let impactRatio: Double
    let changeCount: Int
    let dominantStatus: String
}

struct RailStatusChangeDTO: Decodable {
    let at: String
    let fromStatus: String
    let toStatus: String
    let impactingUser: Bool
    let impactLevel: String
    let impactScore: Int
}

