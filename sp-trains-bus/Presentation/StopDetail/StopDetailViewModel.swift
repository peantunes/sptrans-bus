import Foundation
import Combine

class StopDetailViewModel: ObservableObject {
    @Published var stop: Stop
    @Published var arrivals: [Arrival] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isFavorite: Bool = false

    private let getArrivalsUseCase: GetArrivalsUseCase
    private let storageService: StorageServiceProtocol
    private var timer: Timer?

    init(stop: Stop, getArrivalsUseCase: GetArrivalsUseCase, storageService: StorageServiceProtocol) {
        self.stop = stop
        self.getArrivalsUseCase = getArrivalsUseCase
        self.storageService = storageService
        self.isFavorite = storageService.isFavorite(stopId: stop.stopId)
    }

    func loadArrivals() {
        isLoading = true
        errorMessage = nil

        Task {
            await fetchArrivals()
        }
    }

    @MainActor
    func refreshArrivals() async {
        isLoading = true
        errorMessage = nil
        await fetchArrivals()
    }

    @MainActor
    private func fetchArrivals() async {
        do {
            let fetchedArrivals = try await getArrivalsUseCase.execute(stopId: stop.stopId, limit: 10)
            self.arrivals = fetchedArrivals
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func toggleFavorite() {
        if isFavorite {
            storageService.removeFavorite(stop: stop)
        } else {
            storageService.saveFavorite(stop: stop)
        }
        isFavorite.toggle()
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
