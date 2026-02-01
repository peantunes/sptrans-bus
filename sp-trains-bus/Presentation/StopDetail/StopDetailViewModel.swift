import Foundation
import Combine

class StopDetailViewModel: ObservableObject {
    @Published var stop: Stop
    @Published var arrivals: [Arrival] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let getArrivalsUseCase: GetArrivalsUseCase
    private var timer: Timer?

    init(stop: Stop, getArrivalsUseCase: GetArrivalsUseCase) {
        self.stop = stop
        self.getArrivalsUseCase = getArrivalsUseCase
    }

    func loadArrivals() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetchedArrivals = try await getArrivalsUseCase.execute(stopId: stop.stopId, limit: 10)
                DispatchQueue.main.async {
                    self.arrivals = fetchedArrivals
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func startRefreshingArrivals() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.loadArrivals()
        }
    }

    func stopRefreshingArrivals() {
        timer?.invalidate()
        timer = nil
    }
}
