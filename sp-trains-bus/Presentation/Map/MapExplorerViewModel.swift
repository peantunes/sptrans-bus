import Foundation
import Combine
import MapKit

class MapExplorerViewModel: NSObject, ObservableObject {
    @Published var region: MKCoordinateRegion
    @Published var stops: [Stop] = []
    @Published var railLines: [RailMapLine] = SaoPauloRailNetwork.fallbackLines
    @Published var weatherSnapshot: WeatherSnapshot?
    @Published var isLoadingWeather: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showRefreshButton: Bool = false
    @Published var searchQuery: String = ""
    @Published var searchSuggestions: [MKLocalSearchCompletion] = []
    @Published var isSearchingLocation: Bool = false
    @Published var searchErrorMessage: String?

    private let getNearbyStopsUseCase: GetNearbyStopsUseCase
    private let getTripRouteUseCase: GetTripRouteUseCase?
    private let weatherService: WeatherServiceProtocol
    private let locationService: LocationServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let fileManager: FileManager
    private let calendar: Calendar
    private let searchCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    private var regionChangeWorkItem: DispatchWorkItem?
    private var lastLoadedRegion: MKCoordinateRegion?
    private var railNetworkLoadTask: Task<Void, Never>?
    private var weatherLoadTask: Task<Void, Never>?
    private let railNetworkCacheFileName = "rail_network_cache_v2.json"

    init(
        getNearbyStopsUseCase: GetNearbyStopsUseCase,
        locationService: LocationServiceProtocol,
        getTripRouteUseCase: GetTripRouteUseCase? = nil,
        weatherService: WeatherServiceProtocol,
        analyticsService: AnalyticsServiceProtocol = NoOpAnalyticsService(),
        fileManager: FileManager = .default,
        calendar: Calendar = .current
    ) {
        self.getNearbyStopsUseCase = getNearbyStopsUseCase
        self.locationService = locationService
        self.getTripRouteUseCase = getTripRouteUseCase
        self.weatherService = weatherService
        self.analyticsService = analyticsService
        self.fileManager = fileManager
        self.calendar = calendar

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

    deinit {
        railNetworkLoadTask?.cancel()
        weatherLoadTask?.cancel()
    }

    private func setupRegionObserver() {
        $region
            .dropFirst() // Skip initial value
//            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
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

    func loadRailNetworkIfNeeded() {
        guard railNetworkLoadTask == nil else { return }
        railNetworkLoadTask = Task { [weak self] in
            await self?.loadRailNetwork()
        }
    }

    func loadWeatherIfNeeded() {
        guard weatherLoadTask == nil else { return }
        weatherLoadTask = Task { [weak self] in
            await self?.loadWeather()
        }
    }

    func refreshWeather() {
        weatherLoadTask?.cancel()
        weatherLoadTask = Task { [weak self] in
            await self?.loadWeather()
        }
    }

    private func loadWeather() async {
        await MainActor.run {
            self.isLoadingWeather = true
        }

        let targetLocation = resolveWeatherLocation()
        do {
            let snapshot = try await weatherService.fetchDailyWeather(for: targetLocation)
            await MainActor.run {
                self.weatherSnapshot = snapshot
                self.isLoadingWeather = false
            }
            analyticsService.trackEvent(
                name: "map_weather_loaded",
                properties: [
                    "latitude": "\(targetLocation.latitude)",
                    "longitude": "\(targetLocation.longitude)"
                ]
            )
        } catch {
            await MainActor.run {
                self.isLoadingWeather = false
            }
            analyticsService.trackEvent(
                name: "map_weather_load_failed",
                properties: ["error": error.localizedDescription]
            )
        }
    }

    private func resolveWeatherLocation() -> Location {
        let fallback = Location(
            latitude: MKCoordinateRegion.saoPauloMetro.center.latitude,
            longitude: MKCoordinateRegion.saoPauloMetro.center.longitude
        )

        guard let userLocation = locationService.getCurrentLocation() else {
            return fallback
        }

        let userCoordinate = userLocation.toCLLocationCoordinate2D()
        if MKCoordinateRegion.saoPauloMetro.contains(userCoordinate) {
            return userLocation
        }
        return fallback
    }

    private func loadRailNetwork() async {
        var cachedPayload: RailNetworkCachePayload?
        if let payload = loadRailNetworkCachePayload() {
            cachedPayload = payload
            let cachedLines = payload.lines.compactMap { $0.toRailMapLine() }
            if !cachedLines.isEmpty {
                await MainActor.run {
                    self.railLines = cachedLines
                }
                if !isRailNetworkCacheExpired(savedAt: payload.savedAt) {
                    analyticsService.trackEvent(
                        name: "map_rail_network_cache_hit",
                        properties: ["cached_lines_count": "\(cachedLines.count)"]
                    )
                    return
                }
                analyticsService.trackEvent(
                    name: "map_rail_network_cache_stale",
                    properties: ["cached_lines_count": "\(cachedLines.count)"]
                )
            }
        }

        guard let getTripRouteUseCase else { return }

        var lineTrips: [String: TripStop] = [:]

        for source in SaoPauloRailNetwork.apiSources {
            if Task.isCancelled { return }
            do {
                let trip = try await getTripRouteUseCase.execute(tripId: source.tripId)
                lineTrips[source.id] = trip
            } catch {
                analyticsService.trackEvent(
                    name: "map_rail_line_load_failed",
                    properties: [
                        "line_id": source.id,
                        "trip_id": source.tripId,
                        "error": error.localizedDescription
                    ]
                )
            }
        }

        if lineTrips.isEmpty, cachedPayload != nil {
            analyticsService.trackEvent(name: "map_rail_network_refresh_skipped_due_errors")
            return
        }

        let merged = SaoPauloRailNetwork.mergedLines(apiTripsByLineID: lineTrips)
        let cacheLines = await MainActor.run {
            merged.map(RailMapLineCache.init(line:))
        }
        saveRailNetworkCachePayload(
            RailNetworkCachePayload(
                savedAt: Date(),
                lines: cacheLines
            )
        )
        await MainActor.run {
            self.railLines = merged
            self.analyticsService.trackEvent(
                name: "map_rail_network_loaded",
                properties: [
                    "api_lines_loaded_count": "\(lineTrips.count)",
                    "rendered_lines_count": "\(merged.count)"
                ]
            )
        }
    }

    private func loadRailNetworkCachePayload() -> RailNetworkCachePayload? {
        guard let cacheFileURL = railNetworkCacheFileURL() else { return nil }
        guard let data = try? Data(contentsOf: cacheFileURL) else { return nil }
        return try? JSONDecoder().decode(RailNetworkCachePayload.self, from: data)
    }

    private func saveRailNetworkCachePayload(_ payload: RailNetworkCachePayload) {
        guard let cacheFileURL = railNetworkCacheFileURL() else { return }
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            analyticsService.trackEvent(
                name: "map_rail_network_cache_write_failed",
                properties: ["error": error.localizedDescription]
            )
        }
    }

    private func isRailNetworkCacheExpired(savedAt: Date) -> Bool {
        guard let refreshDate = calendar.date(byAdding: .month, value: 3, to: savedAt) else {
            return true
        }
        return Date() >= refreshDate
    }

    private func railNetworkCacheFileURL() -> URL? {
        guard let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let cacheDirectory = appSupportDirectory.appendingPathComponent("MapCache", isDirectory: true)
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            return cacheDirectory.appendingPathComponent(railNetworkCacheFileName)
        } catch {
            analyticsService.trackEvent(
                name: "map_rail_network_cache_directory_failed",
                properties: ["error": error.localizedDescription]
            )
            return nil
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
