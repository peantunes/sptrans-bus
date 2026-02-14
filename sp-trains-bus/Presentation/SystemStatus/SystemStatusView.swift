import SwiftUI

struct SystemStatusView: View {
    @StateObject private var viewModel: SystemStatusViewModel

    init(viewModel: SystemStatusViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OverallStatusCard(status: viewModel.overallStatus, severity: viewModel.overallSeverity)
                    .padding(.horizontal)

                if let generatedAt = viewModel.generatedAt {
                    Text("Última atualização geral: \(generatedAt)")
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
                        title: "Favoritas",
                        subtitle: "Linhas fixadas no topo",
                        lines: viewModel.favoriteLineStatuses
                    )
                    lineSection(
                        title: "Metrô",
                        subtitle: viewModel.metroLastUpdatedAt.map { "Atualizado às \($0)" },
                        lines: viewModel.metroNonFavoriteLineStatuses
                    )
                    lineSection(
                        title: "CPTM",
                        subtitle: viewModel.cptmLastUpdatedAt.map { "Atualizado às \($0)" },
                        lines: viewModel.cptmNonFavoriteLineStatuses
                    )
                }
            }
        }
        .navigationTitle("System Status")
        .onAppear {
            viewModel.loadMetroStatus()
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
                    .padding(.horizontal)
            }
        }
    }
}

#Preview {
    let viewModel = SystemStatusViewModel(getMetroStatusUseCase: GetMetroStatusUseCase())
    return SystemStatusView(viewModel: viewModel)
}
