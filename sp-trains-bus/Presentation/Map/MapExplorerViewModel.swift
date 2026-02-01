import Foundation
import Combine
import MapKit

class MapExplorerViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion
    @Published var stops: [Stop] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showRefreshButton: Bool = false

    private let getNearbyStopsUseCase: GetNearbyStopsUseCase
    private let locationService: LocationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var regionChangeWorkItem: DispatchWorkItem?
    private var lastLoadedRegion: MKCoordinateRegion?

    init(getNearbyStopsUseCase: GetNearbyStopsUseCase, locationService: LocationServiceProtocol) {
        self.getNearbyStopsUseCase = getNearbyStopsUseCase
        self.locationService = locationService

        _region = Published(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333), // Default to São Paulo
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))

        setupRegionObserver()
    }

    private func setupRegionObserver() {
        $region
            .dropFirst() // Skip initial value
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] newRegion in
                self?.handleRegionChange(newRegion)
            }
            .store(in: &cancellables)
    }

    private func handleRegionChange(_ newRegion: MKCoordinateRegion) {
        // Check if region has moved significantly from last loaded region
        guard let lastRegion = lastLoadedRegion else {
            showRefreshButton = true
            return
        }

        let latDiff = abs(newRegion.center.latitude - lastRegion.center.latitude)
        let lonDiff = abs(newRegion.center.longitude - lastRegion.center.longitude)
        let threshold = 0.005 // About 500m movement

        if latDiff > threshold || lonDiff > threshold {
            showRefreshButton = true
        }
    }

    func loadStopsInVisibleRegion() {
        isLoading = true
        errorMessage = nil
        showRefreshButton = false

        Task {
            await fetchStops()
        }
    }

    @MainActor
    func refreshStops() async {
        isLoading = true
        errorMessage = nil
        showRefreshButton = false
        await fetchStops()
    }

    @MainActor
    private func fetchStops() async {
        do {
            locationService.requestLocationPermission()
            let mapLocation = Location(latitude: region.center.latitude, longitude: region.center.longitude)
            let fetchedStops = try await getNearbyStopsUseCase.execute(limit: 50, location: mapLocation)
            self.stops = fetchedStops
            self.lastLoadedRegion = region
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func centerOnUserLocation() {
        locationService.requestLocationPermission()
        if let userLocation = locationService.getCurrentLocation() {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: userLocation.latitude, longitude: userLocation.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            loadStopsInVisibleRegion()
        }
    }
}
