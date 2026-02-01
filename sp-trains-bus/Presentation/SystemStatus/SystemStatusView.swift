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

                OverallStatusCard(status: viewModel.overallStatus)
                    .padding(.horizontal)

                Text("Metro Lines")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)
                    .padding(.horizontal)
                    .padding(.top, 10)

                if viewModel.isLoading {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        viewModel.loadMetroStatus()
                    }
                } else {
                    ForEach(viewModel.metroLines, id: \.line) { line in
                        MetroLineCard(line: line, status: "Normal", description: "Operation normal") // Placeholder status and description
                            .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear(perform: viewModel.loadMetroStatus)
    }
}

#Preview {
    // Mock dependencies for Preview
    let viewModel = SystemStatusViewModel(getMetroStatusUseCase: GetMetroStatusUseCase())
    return SystemStatusView(viewModel: viewModel)
}
