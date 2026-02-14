import Foundation

struct RailStatusResponseDTO: Decodable {
    let generatedAt: String?
    let metro: RailSourceStatusDTO
    let cptm: RailSourceStatusDTO
}

struct RailSourceStatusDTO: Decodable {
    let source: String
    let available: Bool
    let count: Int
    let lastFetchedAt: String?
    let lastSourceUpdatedAt: String?
    let lines: [RailLineStatusDTO]
}

struct RailLineStatusDTO: Decodable {
    let lineNumber: String
    let lineName: String
    let status: String
    let statusDetail: String
    let statusColor: String
    let sourceUpdatedAt: String?
}

