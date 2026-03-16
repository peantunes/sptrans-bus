import Foundation
import Combine
import StoreKit

enum PremiumSubscriptionProduct {
    static let weekly = "app.lolados.data.weekly"
    static let yearly = "app.lolados.data.yearly"
    static let allIDs: Set<String> = [weekly, yearly]
    static let orderedIDs: [String] = [weekly, yearly]
}

enum PremiumAccessGate {
    private static let hasPremiumKey = "premium_subscription_is_active_v1"
    private static let lastSyncKey = "premium_subscription_last_sync_v1"

    static func hasPremiumAccess(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: hasPremiumKey)
    }

    static func hasAnalyticsAccess(userDefaults: UserDefaults = .standard) -> Bool {
        hasPremiumAccess(userDefaults: userDefaults)
    }

    static func hasDisruptionAlertsAccess(userDefaults: UserDefaults = .standard) -> Bool {
        hasPremiumAccess(userDefaults: userDefaults)
    }

    static func hasArrivalsHistoryAccess(userDefaults: UserDefaults = .standard) -> Bool {
        hasPremiumAccess(userDefaults: userDefaults)
    }

    static func updatePremiumAccess(_ hasAccess: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(hasAccess, forKey: hasPremiumKey)
        userDefaults.set(Date(), forKey: lastSyncKey)
    }
}

enum PremiumPurchaseResult {
    case success
    case pending
    case cancelled
    case unavailable
    case unverified
    case failed
}

enum PremiumRestoreResult {
    case restored
    case noActiveSubscription
    case failed
}

@MainActor
final class PremiumSubscriptionStore: ObservableObject {
    static let shared = PremiumSubscriptionStore()

    @Published private(set) var hasPremiumAccess: Bool
    @Published private(set) var productsByID: [String: Product] = [:]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isRefreshingEntitlements = false

    private let userDefaults: UserDefaults
    private var transactionUpdatesTask: Task<Void, Never>?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hasPremiumAccess = PremiumAccessGate.hasPremiumAccess(userDefaults: userDefaults)
        self.transactionUpdatesTask = observeTransactionUpdates()

        Task {
            await refreshEntitlements()
            await loadProductsIfNeeded()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var premiumProducts: [Product] {
        PremiumSubscriptionProduct.orderedIDs.compactMap { productsByID[$0] }
    }

    func loadProductsIfNeeded() async {
        guard productsByID.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: PremiumSubscriptionProduct.allIDs)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            productsByID = [:]
        }
    }

    func refreshEntitlements() async {
        isRefreshingEntitlements = true
        let hasAccess = await Self.resolveHasActiveSubscription()
        hasPremiumAccess = hasAccess
        PremiumAccessGate.updatePremiumAccess(hasAccess, userDefaults: userDefaults)
        isRefreshingEntitlements = false
    }

    func purchase(productID: String) async -> PremiumPurchaseResult {
        guard let product = productsByID[productID] else {
            await loadProductsIfNeeded()
            guard let reloadedProduct = productsByID[productID] else {
                return .unavailable
            }
            return await purchase(product: reloadedProduct)
        }

        return await purchase(product: product)
    }

    func restorePurchases() async -> PremiumRestoreResult {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return hasPremiumAccess ? .restored : .noActiveSubscription
        } catch {
            return .failed
        }
    }

    private func purchase(product: Product) async -> PremiumPurchaseResult {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    return hasPremiumAccess ? .success : .failed
                case .unverified:
                    return .unverified
                }
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        let premiumIDs = PremiumSubscriptionProduct.allIDs
        return Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                guard premiumIDs.contains(transaction.productID) else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    private static func resolveHasActiveSubscription() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard PremiumSubscriptionProduct.allIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            return true
        }
        return false
    }
}
