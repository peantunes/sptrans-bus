import SwiftUI
import StoreKit

struct TipDeveloperSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var productsByID: [String: Product] = [:]
    @State private var isLoadingProducts = true
    @State private var activePurchaseID: String?
    @State private var alertMessage: String?

    private let options: [TipOption] = [
        TipOption(
            id: "app.lolados.sptrans.tip.small",
            titleKey: "settings.tip.option.small.title",
            subtitleKey: "settings.tip.option.small.subtitle"
        ),
        TipOption(
            id: "app.lolados.sptrans.tip.medium",
            titleKey: "settings.tip.option.medium.title",
            subtitleKey: "settings.tip.option.medium.subtitle"
        ),
        TipOption(
            id: "app.lolados.sptrans.tip.large",
            titleKey: "settings.tip.option.large.title",
            subtitleKey: "settings.tip.option.large.subtitle"
        )
    ]

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
        } catch {
            alertMessage = localized("settings.tip.error.load_products")
        }
    }

    private func purchase(_ option: TipOption) async {
        guard let product = productsByID[option.id] else {
            alertMessage = localized("settings.tip.error.option_unavailable")
            return
        }

        activePurchaseID = option.id
        defer { activePurchaseID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    alertMessage = localized("settings.tip.purchase.thank_you")
                case .unverified:
                    alertMessage = localized("settings.tip.purchase.unverified")
                }
            case .pending:
                alertMessage = localized("settings.tip.purchase.pending")
            case .userCancelled:
                break
            @unknown default:
                alertMessage = localized("settings.tip.error.purchase_failed")
            }
        } catch {
            alertMessage = localized("settings.tip.error.purchase_failed")
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
