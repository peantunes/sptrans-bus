import Foundation

struct RailAlertSubscriptionStateEnvelopeDTO: Decodable {
    let success: Bool
    let state: RailAlertSubscriptionStateDTO
}

struct RailAlertSubscriptionUpdateResponseDTO: Decodable {
    let success: Bool
    let action: String
    let subscriptionCount: Int
    let state: RailAlertSubscriptionStateDTO
}

struct RailAlertSubscriptionStateDTO: Decodable {
    let installationId: String
    let platform: String
    let apnsToken: String?
    let notificationsEnabled: Bool
    let authorizationStatus: String?
    let locale: String?
    let timezone: String?
    let appVersion: String?
    let buildVersion: String?
    let lastSeenAt: String?
    let subscriptions: [RailAlertSubscriptionLineDTO]
}

struct RailAlertSubscriptionLineDTO: Decodable {
    let lineId: String
    let source: String
    let lineNumber: String
    let lineName: String
}

struct RailAlertSubscriptionUpdateRequestDTO: Encodable {
    let installationId: String
    let action: String
    let platform: String
    let apnsToken: String?
    let notificationsEnabled: Bool
    let authorizationStatus: String
    let locale: String
    let timezone: String
    let appVersion: String
    let buildVersion: String
    let lines: [RailAlertSubscriptionLineRequestDTO]
}

struct RailAlertSubscriptionLineRequestDTO: Encodable {
    let lineId: String
    let source: String
    let lineNumber: String
    let lineName: String
}

