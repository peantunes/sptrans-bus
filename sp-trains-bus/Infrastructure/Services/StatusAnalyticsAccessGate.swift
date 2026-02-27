import Foundation

enum StatusAnalyticsTipTier: Int {
    case none = 0
    case small = 1
    case medium = 2
    case large = 3

    var unlocksAnalytics: Bool {
        rawValue >= StatusAnalyticsTipTier.large.rawValue
    }

    var unlocksArrivalsHistory: Bool {
        rawValue >= StatusAnalyticsTipTier.medium.rawValue
    }
}

enum StatusAnalyticsTipProduct {
    static let small = "app.lolados.sptrans.tip.small"
    static let medium = "app.lolados.sptrans.tip.medium"
    static let large = "app.lolados.sptrans.tip.large"
}

enum StatusAnalyticsAccessGate {
    private static let tipTierKey = "status_analytics_tip_tier"

    static func currentTier(userDefaults: UserDefaults = .standard) -> StatusAnalyticsTipTier {
        let rawValue = userDefaults.integer(forKey: tipTierKey)
        return StatusAnalyticsTipTier(rawValue: rawValue) ?? .none
    }

    static func hasAccess(userDefaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        return true
        #else
        return currentTier(userDefaults: userDefaults).unlocksAnalytics
        #endif
    }

    static func hasArrivalsHistoryAccess(userDefaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        return true
        #else
        return currentTier(userDefaults: userDefaults).unlocksArrivalsHistory
        #endif
    }

    static func recordSuccessfulPurchase(productID: String, userDefaults: UserDefaults = .standard) {
        guard let purchasedTier = tier(for: productID) else { return }
        let existingTier = currentTier(userDefaults: userDefaults)
        let nextTier = max(existingTier.rawValue, purchasedTier.rawValue)
        userDefaults.set(nextTier, forKey: tipTierKey)
    }

    private static func tier(for productID: String) -> StatusAnalyticsTipTier? {
        switch productID {
        case StatusAnalyticsTipProduct.small:
            return .small
        case StatusAnalyticsTipProduct.medium:
            return .medium
        case StatusAnalyticsTipProduct.large:
            return .large
        default:
            return nil
        }
    }
}
