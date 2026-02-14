import SwiftUI

struct SystemStatusView: View {
    @StateObject private var viewModel: SystemStatusViewModel

    init(viewModel: SystemStatusViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("System Status")
                    .font(AppFonts.largeTitle())
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.text)
                    .padding(.horizontal)

                OverallStatusCard(status: viewModel.overallStatus, severity: viewModel.overallSeverity)
                    .padding(.horizontal)

                if viewModel.isLoading {
                    LoadingView()
                        .padding(.top, 20)
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        viewModel.loadMetroStatus(forceRefresh: true)
                    }
                    .padding(.top, 10)
                } else {
                    lineSection(title: "Metrô", lines: viewModel.metroLineStatuses)
                    lineSection(title: "CPTM", lines: viewModel.cptmLineStatuses)
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadMetroStatus()
        }
    }

    @ViewBuilder
    private func lineSection(title: String, lines: [RailLineStatusItem]) -> some View {
        if !lines.isEmpty {
            Text(title)
                .font(AppFonts.headline())
                .foregroundColor(AppColors.text)
                .padding(.horizontal)
                .padding(.top, 10)

            ForEach(lines) { line in
                MetroLineCard(line: line)
                    .padding(.horizontal)
            }
        }
    }
}

#Preview {
    let viewModel = SystemStatusViewModel(getMetroStatusUseCase: GetMetroStatusUseCase())
    return SystemStatusView(viewModel: viewModel)
}

