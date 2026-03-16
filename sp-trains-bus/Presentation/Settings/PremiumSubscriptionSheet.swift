import SwiftUI
import StoreKit

struct PremiumSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionStore = PremiumSubscriptionStore.shared

    @State private var activePurchaseID: String?
    @State private var isRestoringPurchases = false
    @State private var alertMessage: String?
    @State private var selectedProductID: String = PremiumSubscriptionProduct.yearly

    let analyticsService: AnalyticsServiceProtocol
    let source: String
    let onUnlocked: (() -> Void)?

    init(
        analyticsService: AnalyticsServiceProtocol = NoOpAnalyticsService(),
        source: String,
        onUnlocked: (() -> Void)? = nil
    ) {
        self.analyticsService = analyticsService
        self.source = source
        self.onUnlocked = onUnlocked
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        AppColors.background,
                        AppColors.primary.opacity(0.16),
                        AppColors.accent.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heroCard
                        featureSection
                        plansSection
                        restoreSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }

                if subscriptionStore.isLoadingProducts {
                    ProgressView(localized("premium.loading_products"))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomCTA
            }
            .navigationTitle(localized("premium.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("common.done")) {
                        dismiss()
                    }
                }
            }
            .task {
                analyticsService.trackScreen(name: "PremiumSubscriptionSheet", className: "PremiumSubscriptionSheet")
                analyticsService.trackEvent(
                    name: "premium_sheet_opened",
                    properties: ["source": source]
                )
                await subscriptionStore.refreshEntitlements()
                await subscriptionStore.loadProductsIfNeeded()
            }
            .alert(
                localized("premium.purchase.alert.title"),
                isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { _ in alertMessage = nil }
                )
            ) {
                Button(localized("common.ok"), role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.accent, AppColors.primary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 54, height: 54)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text(localized("premium.hero.badge"))
                        .font(AppFonts.caption().bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.statusNormal.opacity(0.16))
                        .foregroundColor(AppColors.statusNormal)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("premium.hero.title"))
                        .font(AppFonts.title2().bold())
                        .foregroundColor(AppColors.text)

                    Text(localized("premium.description"))
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.text.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    heroStat(symbol: "sparkles", textKey: "premium.hero.same_features")
                    heroStat(symbol: "calendar.badge.clock", textKey: "premium.hero.weekly_yearly")
                    heroStat(symbol: "xmark.circle", textKey: "premium.hero.cancel_anytime")
                }
            }
        }
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("premium.features.title"))
                .font(AppFonts.headline())
                .foregroundColor(AppColors.text)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                featureCard(emoji: "📈", titleKey: "premium.features.analytics")
                featureCard(emoji: "🔔", titleKey: "premium.features.alerts")
                featureCard(emoji: "🕒", titleKey: "premium.features.arrivals")
            }
        }
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized("premium.options.title"))
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Spacer()

                Text(localized("premium.plan.note"))
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.65))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                planCard(for: PremiumSubscriptionProduct.yearly)
                planCard(for: PremiumSubscriptionProduct.weekly)
            }
        }
    }

    private var restoreSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(AppColors.primary)
                    Text(localized("premium.restore.title"))
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)
                }

                Text(localized("premium.restore.subtitle"))
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.75))

                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRestoringPurchases {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }

                        Text(localized("premium.restore.button"))
                            .font(AppFonts.subheadline().bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(isRestoringPurchases || activePurchaseID != nil)
            }
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await purchaseSelectedPlan()
                }
            } label: {
                HStack(spacing: 10) {
                    if activePurchaseID == resolvedSelectedProductID {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: selectedProductIcon)
                            .font(.headline)
                    }

                    Text(ctaTitle)
                        .font(AppFonts.headline())
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accent, AppColors.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedProduct == nil || activePurchaseID != nil || isRestoringPurchases)

            Text(localized("premium.cta.footnote"))
                .font(AppFonts.caption2())
                .foregroundColor(AppColors.text.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func planCard(for productID: String) -> some View {
        let isSelected = resolvedSelectedProductID == productID
        let product = subscriptionStore.productsByID[productID]
        let priceText = product?.displayPrice ?? localized("premium.unavailable")
        let isYearly = productID == PremiumSubscriptionProduct.yearly
        let titleKey = isYearly ? "premium.option.yearly.title" : "premium.option.weekly.title"
        let subtitleKey = isYearly ? "premium.option.yearly.subtitle" : "premium.option.weekly.subtitle"
        let symbol = isYearly ? "sparkles.rectangle.stack.fill" : "calendar.badge.clock"

        Button {
            selectedProductID = productID
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill((isYearly ? AppColors.accent : AppColors.primary).opacity(0.16))
                                .frame(width: 46, height: 46)

                            Image(systemName: symbol)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(isYearly ? AppColors.accent : AppColors.primary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(localized(titleKey))
                                    .font(AppFonts.title3().bold())
                                    .foregroundColor(AppColors.text)

                                if isYearly {
                                    Text(localized("premium.option.yearly.badge"))
                                        .font(AppFonts.caption2().bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AppColors.accent.opacity(0.16))
                                        .foregroundColor(AppColors.accent)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(localized(subtitleKey))
                                .font(AppFonts.subheadline())
                                .foregroundColor(AppColors.text.opacity(0.76))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(isSelected ? AppColors.statusNormal : AppColors.text.opacity(0.28))
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text(priceText)
                            .font(AppFonts.title2().bold())
                            .foregroundColor(AppColors.text)

                        Spacer()

                        Text(localized("premium.plan.all_features"))
                            .font(AppFonts.caption().bold())
                            .foregroundColor(AppColors.text.opacity(0.72))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        isSelected
                        ? (isYearly ? AppColors.accent : AppColors.primary)
                        : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .scaleEffect(isSelected ? 1.0 : 0.985)
        }
        .buttonStyle(.plain)
        .disabled(activePurchaseID != nil || isRestoringPurchases || product == nil)
    }

    private func featureCard(emoji: String, titleKey: String) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.primary.opacity(0.14))
                        .frame(width: 42, height: 42)

                    Text(emoji)
                        .font(.system(size: 24))
                }

                Text(localized(titleKey))
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.text)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.statusNormal)
            }
        }
    }

    private func heroStat(symbol: String, textKey: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
            Text(localized(textKey))
                .font(AppFonts.caption())
                .lineLimit(1)
        }
        .foregroundColor(AppColors.text.opacity(0.78))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AppColors.background.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var selectedProduct: Product? {
        subscriptionStore.productsByID[resolvedSelectedProductID]
    }

    private var resolvedSelectedProductID: String {
        if subscriptionStore.productsByID[selectedProductID] != nil {
            return selectedProductID
        }

        return PremiumSubscriptionProduct.orderedIDs.first { subscriptionStore.productsByID[$0] != nil } ?? selectedProductID
    }

    private var selectedProductIcon: String {
        resolvedSelectedProductID == PremiumSubscriptionProduct.yearly
        ? "sparkles.rectangle.stack.fill"
        : "calendar.badge.clock"
    }

    private var ctaTitle: String {
        let titleKey = resolvedSelectedProductID == PremiumSubscriptionProduct.yearly
        ? "premium.option.yearly.title"
        : "premium.option.weekly.title"
        let price = selectedProduct?.displayPrice ?? localized("premium.unavailable")
        return String(format: localized("premium.cta.subscribe_format"), localized(titleKey), price)
    }

    private func purchaseSelectedPlan() async {
        await purchase(productID: resolvedSelectedProductID)
    }

    private func purchase(productID: String) async {
        activePurchaseID = productID
        defer { activePurchaseID = nil }

        analyticsService.trackEvent(
            name: "premium_purchase_started",
            properties: [
                "source": source,
                "product_id": productID
            ]
        )

        let result = await subscriptionStore.purchase(productID: productID)
        switch result {
        case .success:
            analyticsService.trackEvent(
                name: "premium_purchase_succeeded",
                properties: [
                    "source": source,
                    "product_id": productID
                ]
            )
            onUnlocked?()
            dismiss()
        case .pending:
            alertMessage = localized("premium.purchase.pending")
        case .cancelled:
            analyticsService.trackEvent(
                name: "premium_purchase_cancelled",
                properties: [
                    "source": source,
                    "product_id": productID
                ]
            )
        case .unavailable:
            alertMessage = localized("premium.error.option_unavailable")
        case .unverified:
            alertMessage = localized("premium.purchase.unverified")
        case .failed:
            alertMessage = localized("premium.error.purchase_failed")
        }
    }

    private func restorePurchases() async {
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        let result = await subscriptionStore.restorePurchases()
        switch result {
        case .restored:
            analyticsService.trackEvent(
                name: "premium_restore_succeeded",
                properties: ["source": source]
            )
            onUnlocked?()
            dismiss()
        case .noActiveSubscription:
            alertMessage = localized("premium.restore.no_active_subscription")
        case .failed:
            analyticsService.trackEvent(
                name: "premium_restore_failed",
                properties: ["source": source]
            )
            alertMessage = localized("premium.restore.failed")
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

#Preview {
    PremiumSubscriptionSheet(source: "preview")
}
