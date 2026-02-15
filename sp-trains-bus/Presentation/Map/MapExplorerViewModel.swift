import Foundation
import Combine
import MapKit

class MapExplorerViewModel: NSObject, ObservableObject {
    @Published var region: MKCoordinateRegion
    @Published var stops: [Stop] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showRefreshButton: Bool = false
    @Published var searchQuery: String = ""
    @Published var searchSuggestions: [MKLocalSearchCompletion] = []
    @Published var isSearchingLocation: Bool = false
    @Published var searchErrorMessage: String?

    private let getNearbyStopsUseCase: GetNearbyStopsUseCase
    private let locationService: LocationServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let searchCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    private var regionChangeWorkItem: DispatchWorkItem?
    private var lastLoadedRegion: MKCoordinateRegion?

    init(
        getNearbyStopsUseCase: GetNearbyStopsUseCase,
        locationService: LocationServiceProtocol,
        analyticsService: AnalyticsServiceProtocol = NoOpAnalyticsService()
    ) {
        self.getNearbyStopsUseCase = getNearbyStopsUseCase
        self.locationService = locationService
        self.analyticsService = analyticsService

        _region = Published(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333), // Default to São Paulo
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))

        super.init()
        
        setupRegionObserver()
        setupSearchObserver()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        searchCompleter.region = .saoPauloMetro
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

    private func setupSearchObserver() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                self.searchErrorMessage = nil
                if query.isEmpty {
                    self.searchSuggestions = []
                } else {
                    self.searchCompleter.queryFragment = query
                }
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
        analyticsService.trackEvent(name: "map_stops_load_requested", properties: ["trigger": "visible_region"])

        Task {
            await fetchStops()
        }
    }

    @MainActor
    func refreshStops() async {
        isLoading = true
        errorMessage = nil
        showRefreshButton = false
        analyticsService.trackEvent(name: "map_stops_load_requested", properties: ["trigger": "manual_refresh"])
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
            analyticsService.trackEvent(
                name: "map_stops_load_succeeded",
                properties: [
                    "stops_count": "\(fetchedStops.count)",
                    "latitude": "\(mapLocation.latitude)",
                    "longitude": "\(mapLocation.longitude)"
                ]
            )
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            analyticsService.trackEvent(
                name: "map_stops_load_failed",
                properties: ["error": error.localizedDescription]
            )
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
            analyticsService.trackEvent(
                name: "map_center_on_user_location",
                properties: [
                    "latitude": "\(userLocation.latitude)",
                    "longitude": "\(userLocation.longitude)"
                ]
            )
        } else {
            analyticsService.trackEvent(name: "map_center_on_user_location_failed")
        }
    }

    @MainActor
    func submitSearch() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        analyticsService.trackEvent(
            name: "map_search_submitted",
            properties: [
                "query": trimmed,
                "query_length": "\(trimmed.count)"
            ]
        )

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.region = .saoPauloMetro
        await performSearch(request: request)
    }

    @MainActor
    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        analyticsService.trackEvent(
            name: "map_search_suggestion_selected",
            properties: ["title": suggestion.title]
        )

        let request = MKLocalSearch.Request(completion: suggestion)
        request.region = .saoPauloMetro
        await performSearch(request: request)
    }

    @MainActor
    private func performSearch(request: MKLocalSearch.Request) async {
        isSearchingLocation = true
        searchErrorMessage = nil

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let mapItem = response.mapItems.first else {
                searchErrorMessage = "No locations found for that search."
                isSearchingLocation = false
                analyticsService.trackEvent(name: "map_search_no_results")
                return
            }

            if !MKCoordinateRegion.saoPauloMetro.contains(mapItem.placemark.coordinate) {
                searchErrorMessage = "Search is limited to the Sao Paulo metro area."
                isSearchingLocation = false
                analyticsService.trackEvent(name: "map_search_outside_supported_area")
                return
            }

            applySearchResult(mapItem)
            searchSuggestions = []
        } catch {
            searchErrorMessage = error.localizedDescription
            analyticsService.trackEvent(
                name: "map_search_failed",
                properties: ["error": error.localizedDescription]
            )
        }

        isSearchingLocation = false
    }

    @MainActor
    private func applySearchResult(_ mapItem: MKMapItem) {
        let coordinate = mapItem.placemark.coordinate
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        lastLoadedRegion = region
        showRefreshButton = false
        loadStopsInVisibleRegion()
        analyticsService.trackEvent(
            name: "map_search_result_applied",
            properties: [
                "title": mapItem.name ?? "",
                "latitude": "\(coordinate.latitude)",
                "longitude": "\(coordinate.longitude)"
            ]
        )
    }
}

extension MapExplorerViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.searchSuggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.searchErrorMessage = error.localizedDescription
        }
    }
}
