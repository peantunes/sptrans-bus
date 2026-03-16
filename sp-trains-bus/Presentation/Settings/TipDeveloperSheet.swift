import SwiftUI
import StoreKit

struct TipDeveloperSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode

    @State private var productsByID: [String: Product] = [:]
    @State private var isLoadingProducts = true
    @State private var isRestoringPurchases = false
    @State private var activePurchaseID: String?
    @State private var alertMessage: String?
    let analyticsService: AnalyticsServiceProtocol

    private let options: [TipOption] = [
        TipOption(
            id: TipProductIDs.small,
            titleKey: "settings.tip.option.small.title",
            subtitleKey: "settings.tip.option.small.subtitle"
        ),
        TipOption(
            id: TipProductIDs.medium,
            titleKey: "settings.tip.option.medium.title",
            subtitleKey: "settings.tip.option.medium.subtitle"
        ),
        TipOption(
            id: TipProductIDs.large,
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

                Section {
                    Button {
                        Task {
                            await restorePurchases()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isRestoringPurchases {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise.circle")
                                    .foregroundColor(AppColors.primary)
                            }

                            Text(localized("settings.tip.restore.button"))
                                .font(AppFonts.body())
                                .foregroundColor(AppColors.text)
                        }
                    }
                    .disabled(isRestoringPurchases || activePurchaseID != nil)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("common.done")) {
                        closeSheet()
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
                    alertMessage = localized("settings.tip.purchase.thank_you")
                    analyticsService.trackEvent(
                        name: "tip_purchase_succeeded",
                        properties: [
                            "product_id": option.id
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

    private func restorePurchases() async {
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await AppStore.sync()
            alertMessage = localized("settings.tip.restore.success")
            analyticsService.trackEvent(name: "tip_restore_succeeded")
        } catch {
            alertMessage = localized("settings.tip.restore.failed")
            analyticsService.trackEvent(
                name: "tip_restore_failed",
                properties: ["error": error.localizedDescription]
            )
        }
    }

    private func closeSheet() {
        if presentationMode.wrappedValue.isPresented {
            presentationMode.wrappedValue.dismiss()
        } else {
            dismiss()
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

private enum TipProductIDs {
    static let small = "app.lolados.sptrans.tip.small"
    static let medium = "app.lolados.sptrans.tip.medium"
    static let large = "app.lolados.sptrans.tip.large"
}

#Preview {
    TipDeveloperSheet()
}
