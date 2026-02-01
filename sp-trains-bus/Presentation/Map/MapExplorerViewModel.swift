import Foundation
import Combine
import MapKit

class MapExplorerViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion
    @Published var stops: [Stop] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let getNearbyStopsUseCase: GetNearbyStopsUseCase
    private let locationService: LocationServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(getNearbyStopsUseCase: GetNearbyStopsUseCase, locationService: LocationServiceProtocol) {
        self.getNearbyStopsUseCase = getNearbyStopsUseCase
        self.locationService = locationService

        _region = Published(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333), // Default to São Paulo
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    func loadStopsInVisibleRegion() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                locationService.requestLocationPermission()
                let mapLocation = Location(latitude: region.center.latitude, longitude: region.center.longitude)
                let fetchedStops = try await getNearbyStopsUseCase.execute(limit: 50, location: mapLocation) // Fetch more stops for map
                DispatchQueue.main.async {
                    self.stops = fetchedStops
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
}
