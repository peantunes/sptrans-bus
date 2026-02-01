import Foundation
import Combine

class SystemStatusViewModel: ObservableObject {
    @Published var metroLines: [MetroLine] = []
    @Published var overallStatus: String = "Loading..."
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let getMetroStatusUseCase: GetMetroStatusUseCase

    init(getMetroStatusUseCase: GetMetroStatusUseCase) {
        self.getMetroStatusUseCase = getMetroStatusUseCase
    }

    func loadMetroStatus() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Simulate API call
            self.metroLines = self.getMetroStatusUseCase.execute()
            self.updateOverallStatus()
            self.isLoading = false
        }
    }

    private func updateOverallStatus() {
        if metroLines.isEmpty {
            overallStatus = "No data available"
        } else {
            // Simple logic: if any line is not "Normal", status is "Partial Service"
            // For now, all mock data is "Normal", so we will show "Normal Operation"
            overallStatus = "Normal Operation"
        }
    }
}
