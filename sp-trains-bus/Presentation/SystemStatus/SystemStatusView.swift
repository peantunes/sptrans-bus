import SwiftUI

struct SystemStatusView: View {
    @StateObject private var viewModel: SystemStatusViewModel
    @ObservedObject var navigationCoordinator: AppNavigationCoordinator
    @State private var highlightedLineID: String?
    @State private var isShowingAlertSetupPrompt = false
    @State private var isNavigatingToDisruptionAlerts = false
    @State private var hasEvaluatedAlertSetupPrompt = false

    init(viewModel: SystemStatusViewModel, navigationCoordinator: AppNavigationCoordinator) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.navigationCoordinator = navigationCoordinator
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    OverallStatusCard(status: viewModel.overallStatus, severity: viewModel.overallSeverity)
                        .padding(.horizontal)

                    if let generatedAt = viewModel.generatedAt {
                        Text(String(format: localized("status.generated_at_format"), generatedAt))
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.7))
                            .padding(.horizontal)
                    }

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            LoadingView()
                            Spacer()
                        }
                        .padding(.top, 20)
                    } else if let errorMessage = viewModel.errorMessage {
                        ErrorView(message: errorMessage) {
                            viewModel.loadMetroStatus(forceRefresh: true)
                        }
                        .padding(.top, 10)
                    } else {
                        lineSection(
                            title: localized("status.section.favorites"),
                            subtitle: localized("status.section.favorites.subtitle"),
                            lines: viewModel.favoriteLineStatuses
                        )
                        lineSection(
                            title: localized("status.section.metro"),
                            subtitle: viewModel.metroLastUpdatedAt.map { String(format: localized("status.updated_at_format"), $0) },
                            lines: viewModel.metroNonFavoriteLineStatuses
                        )
                        lineSection(
                            title: localized("status.section.cptm"),
                            subtitle: viewModel.cptmLastUpdatedAt.map { String(format: localized("status.updated_at_format"), $0) },
                            lines: viewModel.cptmNonFavoriteLineStatuses
                        )
                    }
                }
            }
            .onChange(of: navigationCoordinator.pendingLineID) { _, _ in
                revealPendingLine(using: proxy)
            }
            .onChange(of: viewModel.metroLineStatuses.count + viewModel.cptmLineStatuses.count) { _, _ in
                revealPendingLine(using: proxy)
                evaluateAlertSetupPromptIfNeeded()
            }
        }
        .navigationTitle(localized("status.title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RailDisruptionAlertsView(viewModel: viewModel.makeDisruptionAlertsViewModel())
                } label: {
                    Image(systemName: "bell.badge")
                        .font(.headline)
                }
                .accessibilityLabel(localized("status.alerts.navigation_title"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RailStatusAnalyticsView(viewModel: viewModel.makeAnalyticsViewModel())
                } label: {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.headline)
                }
                .accessibilityLabel(localized("status.analytics.button.title"))
            }
        }
        .navigationDestination(isPresented: $isNavigatingToDisruptionAlerts) {
            RailDisruptionAlertsView(viewModel: viewModel.makeDisruptionAlertsViewModel())
        }
        .sheet(isPresented: $isShowingAlertSetupPrompt) {
            RailAlertSetupPromptSheet(
                onChooseLines: {
                    await openDisruptionAlertsFromPrompt()
                },
                onDismiss: {
                    isShowingAlertSetupPrompt = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            viewModel.trackScreenOpened()
            viewModel.loadMetroStatus()
            revealPendingLine(using: nil)
            evaluateAlertSetupPromptIfNeeded()
        }
    }

    @ViewBuilder
    private func lineSection(title: String, subtitle: String? = nil, lines: [RailLineStatusItem]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.7))
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            ForEach(lines) { line in
                MetroLineCard(
                    line: line,
                    isFavorite: viewModel.isFavorite(line),
                    onToggleFavorite: { viewModel.toggleFavorite(line) }
                )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(line.id == highlightedLineID ? AppColors.primary : .clear, lineWidth: 2)
                    )
                    .id(line.id)
                    .padding(.horizontal)
            }
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func revealPendingLine(using proxy: ScrollViewProxy?) {
        guard let lineID = navigationCoordinator.pendingLineID else { return }

        let availableLineIDs = Set((viewModel.metroLineStatuses + viewModel.cptmLineStatuses).map(\.id))
        guard availableLineIDs.contains(lineID) else { return }

        highlightedLineID = lineID
        if let proxy {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(lineID, anchor: .center)
            }
        }
        navigationCoordinator.clearPendingLine()

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if highlightedLineID == lineID {
                highlightedLineID = nil
            }
        }
    }

    private func evaluateAlertSetupPromptIfNeeded() {
        guard !hasEvaluatedAlertSetupPrompt else { return }
        guard viewModel.hasDisruptionAlertSetupSupport else { return }

        hasEvaluatedAlertSetupPrompt = true
        Task {
            let shouldShowPrompt = await viewModel.needsDisruptionAlertSetupPrompt()
            await MainActor.run {
                if shouldShowPrompt {
                    isShowingAlertSetupPrompt = true
                }
            }
        }
    }

    private func openDisruptionAlertsFromPrompt() async {
        await viewModel.requestDisruptionAlertNotificationAuthorization()
        await MainActor.run {
            isShowingAlertSetupPrompt = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isNavigatingToDisruptionAlerts = true
            }
        }
    }
}

private struct RailAlertSetupPromptSheet: View {
    @State private var isWorking = false
    let onChooseLines: () async -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.primary.opacity(0.14))
                        .frame(width: 56, height: 56)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("status.alerts.prompt.title"))
                        .font(AppFonts.title3().bold())
                        .foregroundColor(AppColors.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(localized("status.alerts.prompt.message"))
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.text.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button {
                    isWorking = true
                    Task {
                        await onChooseLines()
                        await MainActor.run {
                            isWorking = false
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isWorking {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checklist")
                        }

                        Text(localized("status.alerts.prompt.primary"))
                            .font(AppFonts.headline())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
                .disabled(isWorking)

                Button(localized("status.alerts.prompt.secondary")) {
                    onDismiss()
                }
                .font(AppFonts.subheadline())
                .frame(maxWidth: .infinity)
                .disabled(isWorking)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

#Preview {
    let viewModel = SystemStatusViewModel(getMetroStatusUseCase: GetMetroStatusUseCase())
    return SystemStatusView(viewModel: viewModel, navigationCoordinator: AppNavigationCoordinator())
}
