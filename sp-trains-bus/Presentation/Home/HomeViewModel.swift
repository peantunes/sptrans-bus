import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var nearbyStops: [Stop] = []
    @Published var favoriteStops: [Stop] = []
    @Published var savedPlaces: [UserPlace] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userLocation: Location?

    private let getNearbyStopsUseCase: GetNearbyStopsUseCase
    let locationService: LocationServiceProtocol
    private let storageService: StorageServiceProtocol

    init(getNearbyStopsUseCase: GetNearbyStopsUseCase,
         locationService: LocationServiceProtocol,
         storageService: StorageServiceProtocol) {
        self.getNearbyStopsUseCase = getNearbyStopsUseCase
        self.locationService = locationService
        self.storageService = storageService
        
        // Request location permissions when the ViewModel is initialized
        self.locationService.requestLocationPermission()
    }

    func loadData() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                if userLocation == nil {
                    // Try to get current location if not already set
                    userLocation = locationService.getCurrentLocation() ?? Location.saoPaulo
                }

                guard let currentLocation = userLocation else {
                    throw LocationError.locationUnavailable
                }

                let stops = try await getNearbyStopsUseCase.execute(limit: 5, location: currentLocation)
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
            await MainActor.run {
                self.loadFavoriteStops()
                self.loadSavedPlaces()
            }
        }
    }

    func loadFavoriteStops() {
        favoriteStops = storageService.getFavoriteStops()
    }

    func loadSavedPlaces() {
        savedPlaces = storageService.getSavedPlaces()
    }

    func addFavoriteStop(stop: Stop) {
        storageService.saveFavorite(stop: stop)
        loadFavoriteStops()
    }

    func removeFavoriteStop(stop: Stop) {
        storageService.removeFavorite(stop: stop)
        loadFavoriteStops()
    }

    func savePlace(_ place: UserPlace) {
        storageService.savePlace(place)
        loadSavedPlaces()
    }

    func removePlace(id: UUID) {
        storageService.removePlace(id: id)
        loadSavedPlaces()
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
