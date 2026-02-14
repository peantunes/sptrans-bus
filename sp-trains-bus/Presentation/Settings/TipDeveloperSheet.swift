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
            title: "Small Tip",
            subtitle: "Help keep updates coming."
        ),
        TipOption(
            id: "app.lolados.sptrans.tip.medium",
            title: "Medium Tip",
            subtitle: "Support development and server costs."
        ),
        TipOption(
            id: "app.lolados.sptrans.tip.large",
            title: "Big Tip",
            subtitle: "A huge thanks for supporting the app."
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose a one-time tip to support development.")
                        .font(AppFonts.callout())
                        .foregroundColor(AppColors.text.opacity(0.8))
                        .padding(.vertical, 4)
                }

                Section("Tip Options") {
                    ForEach(options) { option in
                        tipOptionRow(option)
                    }
                }
            }
            .overlay {
                if isLoadingProducts {
                    ProgressView("Loading products...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Tip the Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadProducts()
            }
            .alert("Purchase", isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func tipOptionRow(_ option: TipOption) -> some View {
        let isPurchasing = activePurchaseID == option.id
        let priceText = productsByID[option.id]?.displayPrice ?? "Unavailable"

        Button {
            Task {
                await purchase(option)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.text)

                    Text(option.subtitle)
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
            alertMessage = "Could not load tip products. Please try again later."
        }
    }

    private func purchase(_ option: TipOption) async {
        guard let product = productsByID[option.id] else {
            alertMessage = "This tip option is not available right now."
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
                    alertMessage = "Thank you for your support!"
                case .unverified:
                    alertMessage = "Purchase could not be verified."
                }
            case .pending:
                alertMessage = "Purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                alertMessage = "Purchase failed. Please try again."
            }
        } catch {
            alertMessage = "Purchase failed. Please try again."
        }
    }
}

private struct TipOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
}

#Preview {
    TipDeveloperSheet()
}
