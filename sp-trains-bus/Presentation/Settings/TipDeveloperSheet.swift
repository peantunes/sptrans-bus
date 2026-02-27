import SwiftUI
import StoreKit

struct TipDeveloperSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var productsByID: [String: Product] = [:]
    @State private var isLoadingProducts = true
    @State private var activePurchaseID: String?
    @State private var alertMessage: String?
    let analyticsService: AnalyticsServiceProtocol

    private let options: [TipOption] = [
        TipOption(
            id: StatusAnalyticsTipProduct.small,
            titleKey: "settings.tip.option.small.title",
            subtitleKey: "settings.tip.option.small.subtitle"
        ),
        TipOption(
            id: StatusAnalyticsTipProduct.medium,
            titleKey: "settings.tip.option.medium.title",
            subtitleKey: "settings.tip.option.medium.subtitle"
        ),
        TipOption(
            id: StatusAnalyticsTipProduct.large,
            titleKey: "settings.tip.option.large.title",
            subtitleKey: "settings.tip.option.large.subtitle"
        )
    ]

    init(analyticsService: AnalyticsServiceProtocol = NoOpAnalyticsService()) {
        self.analyticsService = analyticsService
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(localized("settings.tip.description"))
                        .font(AppFonts.callout())
                        .foregroundColor(AppColors.text.opacity(0.8))
                        .padding(.vertical, 4)
                }

                Section(localized("settings.tip.options.title")) {
                    ForEach(options) { option in
                        tipOptionRow(option)
                    }
                }
            }
            .overlay {
                if isLoadingProducts {
                    ProgressView(localized("settings.tip.loading_products"))
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle(localized("settings.tip.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("common.done")) {
                        dismiss()
                    }
                }
            }
            .task {
                analyticsService.trackScreen(name: "TipDeveloperSheet", className: "TipDeveloperSheet")
                analyticsService.trackEvent(name: "tip_modal_opened")
                await loadProducts()
            }
            .alert(localized("settings.tip.purchase.alert.title"), isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })) {
                Button(localized("common.ok"), role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func tipOptionRow(_ option: TipOption) -> some View {
        let isPurchasing = activePurchaseID == option.id
        let priceText = productsByID[option.id]?.displayPrice ?? localized("settings.tip.unavailable")

        Button {
            Task {
                await purchase(option)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized(option.titleKey))
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.text)

                    Text(localized(option.subtitleKey))
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.7))
                }

                Spacer()

                if isPurchasing {
                    ProgressView()
                } else {
                    Text(priceText)
                        .font(AppFonts.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(productsByID[option.id] == nil ? AppColors.text.opacity(0.4) : AppColors.primary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(productsByID[option.id] == nil || activePurchaseID != nil)
    }

    private func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let ids = Set(options.map(\.id))
            let products = try await Product.products(for: ids)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            analyticsService.trackEvent(
                name: "tip_products_loaded",
                properties: ["products_count": "\(products.count)"]
            )
        } catch {
            alertMessage = localized("settings.tip.error.load_products")
            analyticsService.trackEvent(
                name: "tip_products_load_failed",
                properties: ["error": error.localizedDescription]
            )
        }
    }

    private func purchase(_ option: TipOption) async {
        guard let product = productsByID[option.id] else {
            alertMessage = localized("settings.tip.error.option_unavailable")
            analyticsService.trackEvent(
                name: "tip_purchase_unavailable",
                properties: ["product_id": option.id]
            )
            return
        }

        activePurchaseID = option.id
        defer { activePurchaseID = nil }
        analyticsService.trackEvent(
            name: "tip_purchase_started",
            properties: ["product_id": option.id]
        )

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    StatusAnalyticsAccessGate.recordSuccessfulPurchase(productID: option.id)
                    alertMessage = localized("settings.tip.purchase.thank_you")
                    analyticsService.trackEvent(
                        name: "tip_purchase_succeeded",
                        properties: [
                            "product_id": option.id,
                            "analytics_unlocked": StatusAnalyticsAccessGate.hasAccess() ? "true" : "false"
                        ]
                    )
                case .unverified:
                    alertMessage = localized("settings.tip.purchase.unverified")
                    analyticsService.trackEvent(
                        name: "tip_purchase_unverified",
                        properties: ["product_id": option.id]
                    )
                }
            case .pending:
                alertMessage = localized("settings.tip.purchase.pending")
                analyticsService.trackEvent(
                    name: "tip_purchase_pending",
                    properties: ["product_id": option.id]
                )
            case .userCancelled:
                analyticsService.trackEvent(
                    name: "tip_purchase_cancelled",
                    properties: ["product_id": option.id]
                )
                break
            @unknown default:
                alertMessage = localized("settings.tip.error.purchase_failed")
                analyticsService.trackEvent(
                    name: "tip_purchase_failed",
                    properties: ["product_id": option.id]
                )
            }
        } catch {
            alertMessage = localized("settings.tip.error.purchase_failed")
            analyticsService.trackEvent(
                name: "tip_purchase_failed",
                properties: [
                    "product_id": option.id,
                    "error": error.localizedDescription
                ]
            )
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct TipOption: Identifiable {
    let id: String
    let titleKey: String
    let subtitleKey: String
}

#Preview {
    TipDeveloperSheet()
}
