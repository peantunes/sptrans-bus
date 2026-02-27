import SwiftUI
import UIKit
import StoreKit

struct RailDisruptionAlertsView: View {
    @StateObject private var viewModel: RailDisruptionAlertsViewModel
    @Environment(\.openURL) private var openURL
    @State private var promotedProductsByID: [String: Product] = [:]
    @State private var isLoadingPromotedProducts = false
    @State private var activePromotedPurchaseID: String?
    @State private var purchaseAlertMessage: String?

    init(viewModel: RailDisruptionAlertsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !viewModel.isAccessGranted {
                    lockedSection
                } else {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(localized("status.alerts.title"))
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.text)
                            Text(localized("status.alerts.subtitle"))
                                .font(AppFonts.body())
                                .foregroundColor(AppColors.text.opacity(0.84))

                            if viewModel.hasSelectableLines {
                                HStack {
                                    Text(
                                        String(
                                            format: localized("status.alerts.selected_count_format"),
                                            viewModel.selectedCount,
                                            viewModel.lines.count
                                        )
                                    )
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.text.opacity(0.72))

                                    Spacer()

                                    Button {
                                        viewModel.toggleSelectAll()
                                    } label: {
                                        Text(
                                            viewModel.areAllLinesSelected
                                            ? localized("status.alerts.deselect_all")
                                            : localized("status.alerts.select_all")
                                        )
                                        .font(AppFonts.caption().bold())
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }

                    if viewModel.shouldShowSettingsHint {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(localized("status.alerts.notifications_blocked.title"))
                                    .font(AppFonts.subheadline().bold())
                                    .foregroundColor(AppColors.statusAlert)
                                Text(localized("status.alerts.notifications_blocked.message"))
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.text.opacity(0.8))
                                Button(localized("status.alerts.notifications_blocked.open_settings")) {
                                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                    openURL(url)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColors.statusAlert)
                            }
                        }
                    }

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            LoadingView()
                            Spacer()
                        }
                        .padding(.top, 20)
                    } else if viewModel.lines.isEmpty {
                        Text(localized("status.alerts.empty_lines"))
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.text.opacity(0.8))
                    } else {
                        lineSection(title: localized("status.section.metro"), lines: viewModel.metroLines)
                        lineSection(title: localized("status.section.cptm"), lines: viewModel.cptmLines)
                    }

                    if let successMessage = viewModel.successMessage {
                        Text(successMessage)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.statusNormal)
                    }
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.statusAlert)
                    }

                    Button {
                        viewModel.saveSubscriptions()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            Text(localized("status.alerts.save"))
                                .font(AppFonts.headline())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primary)
                    .disabled(viewModel.isSaving)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle(localized("status.alerts.navigation_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.isAccessGranted) {
            guard !viewModel.isAccessGranted else { return }
            await loadPromotedProductsIfNeeded()
        }
        .alert(
            localized("settings.tip.purchase.alert.title"),
            isPresented: Binding(
                get: { purchaseAlertMessage != nil },
                set: { _ in purchaseAlertMessage = nil }
            )
        ) {
            Button(localized("common.ok"), role: .cancel) {}
        } message: {
            Text(purchaseAlertMessage ?? "")
        }
        .onAppear {
            viewModel.refreshAccessStatus()
            viewModel.trackScreenOpened()
            viewModel.loadExistingSubscriptions()
        }
    }

    private var lockedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label(localized("status.alerts.locked.title"), systemImage: "lock.fill")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)

                    Text(localized("status.alerts.locked.message"))
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.text.opacity(0.85))

                    Text(localized("status.alerts.locked.how_to"))
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.75))

                    Text(localized("status.alerts.locked.cta_title"))
                        .font(AppFonts.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.text)
                        .padding(.top, 2)

                    promotedPurchaseButtons

                    #if DEBUG
                    Text(localized("status.alerts.locked.debug_note"))
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.statusNormal)
                    #endif
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localized("status.alerts.locked.preview_title"))
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)

                    VStack(spacing: 8) {
                        previewLineRow(title: "METRO L1 Azul")
                        previewLineRow(title: "METRO L3 Vermelha")
                        previewLineRow(title: "CPTM L11 Coral")
                        previewLineRow(title: "CPTM L10 Turquesa")
                    }
                }
                .redacted(reason: .placeholder)
            }
        }
    }

    private var promotedPurchaseButtons: some View {
        promotedPurchaseButton(
            productID: StatusAnalyticsTipProduct.large,
            titleKey: "settings.tip.option.large.title",
            tint: AppColors.accent
        )
    }

    @ViewBuilder
    private func promotedPurchaseButton(productID: String, titleKey: String, tint: Color) -> some View {
        let isPurchasing = activePromotedPurchaseID == productID
        let price = promotedProductsByID[productID]?.displayPrice ?? localized("settings.tip.unavailable")
        let isEnabled = promotedProductsByID[productID] != nil && activePromotedPurchaseID == nil

        Button {
            Task {
                await purchasePromotedTip(productID: productID)
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "bell.badge.fill")
                        .font(.caption)
                }

                Text(String(format: localized("status.alerts.locked.buy_button_format"), localized(titleKey), price))
                    .font(AppFonts.subheadline())
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled ? tint : AppColors.lightGray.opacity(0.55))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoadingPromotedProducts)
    }

    private func previewLineRow(title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "circle")
                .foregroundColor(AppColors.text.opacity(0.5))
            Text(title)
                .font(AppFonts.body())
                .foregroundColor(AppColors.text)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.background.opacity(0.4))
        )
    }

    @ViewBuilder
    private func lineSection(title: String, lines: [RailDisruptionAlertLine]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                ForEach(lines) { line in
                    Button {
                        viewModel.toggle(line)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: viewModel.isSelected(line) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.isSelected(line) ? AppColors.primary : AppColors.text.opacity(0.5))
                            Text(line.displayName)
                                .font(AppFonts.body())
                                .foregroundColor(AppColors.text)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.isSelected(line) ? AppColors.primary.opacity(0.12) : AppColors.background.opacity(0.4))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func loadPromotedProductsIfNeeded() async {
        guard promotedProductsByID.isEmpty else { return }
        isLoadingPromotedProducts = true
        defer { isLoadingPromotedProducts = false }

        do {
            let ids = Set([StatusAnalyticsTipProduct.large])
            let products = try await Product.products(for: ids)
            promotedProductsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            purchaseAlertMessage = localized("settings.tip.error.load_products")
        }
    }

    private func purchasePromotedTip(productID: String) async {
        guard let product = promotedProductsByID[productID] else {
            purchaseAlertMessage = localized("settings.tip.error.option_unavailable")
            return
        }

        activePromotedPurchaseID = productID
        defer { activePromotedPurchaseID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    StatusAnalyticsAccessGate.recordSuccessfulPurchase(productID: productID)
                    purchaseAlertMessage = localized("status.alerts.locked.purchase_success")
                    viewModel.refreshAccessStatus()
                    viewModel.loadExistingSubscriptions()
                case .unverified:
                    purchaseAlertMessage = localized("settings.tip.purchase.unverified")
                }
            case .pending:
                purchaseAlertMessage = localized("settings.tip.purchase.pending")
            case .userCancelled:
                break
            @unknown default:
                purchaseAlertMessage = localized("settings.tip.error.purchase_failed")
            }
        } catch {
            purchaseAlertMessage = localized("settings.tip.error.purchase_failed")
        }
    }
}
