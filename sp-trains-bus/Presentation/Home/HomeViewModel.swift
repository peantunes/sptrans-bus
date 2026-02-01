import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var nearbyStops: [Stop] = []
    @Published var favoriteStops: [Stop] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let getNearbyStopsUseCase: GetNearbyStopsUseCase
    private let locationService: LocationServiceProtocol
    private let storageService: StorageServiceProtocol

    init(getNearbyStopsUseCase: GetNearbyStopsUseCase,
         locationService: LocationServiceProtocol,
         storageService: StorageServiceProtocol) {
        self.getNearbyStopsUseCase = getNearbyStopsUseCase
        self.locationService = locationService
        self.storageService = storageService
    }

    func loadData() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                locationService.requestLocationPermission()
                let stops = try await getNearbyStopsUseCase.execute(limit: 5)
                DispatchQueue.main.async {
                    self.nearbyStops = stops
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
            loadFavoriteStops()
        }
    }

    func loadFavoriteStops() {
        favoriteStops = storageService.getFavoriteStops()
    }

    func addFavoriteStop(stop: Stop) {
        storageService.saveFavorite(stop: stop)
        loadFavoriteStops()
    }

    func removeFavoriteStop(stop: Stop) {
        storageService.removeFavorite(stop: stop)
        loadFavoriteStops()
    }

    func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:
            return "Good Morning"
        case 12..<18:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }
}
