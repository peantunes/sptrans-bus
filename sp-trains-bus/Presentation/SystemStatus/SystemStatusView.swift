import SwiftUI

struct SystemStatusView: View {
    @StateObject private var viewModel: SystemStatusViewModel
    @ObservedObject var navigationCoordinator: AppNavigationCoordinator
    @State private var highlightedLineID: String?

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
        .onAppear {
            viewModel.trackScreenOpened()
            viewModel.loadMetroStatus()
            revealPendingLine(using: nil)
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
}

#Preview {
    let viewModel = SystemStatusViewModel(getMetroStatusUseCase: GetMetroStatusUseCase())
    return SystemStatusView(viewModel: viewModel, navigationCoordinator: AppNavigationCoordinator())
}
