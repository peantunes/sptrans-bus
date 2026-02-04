import Foundation
import Combine
import MapKit
import CoreLocation

class SearchViewModel: NSObject, ObservableObject {
    @Published var searchText: String = ""
    @Published var searchSuggestions: [MKLocalSearchCompletion] = []
    @Published var nearbyStops: [Stop] = []
    @Published var selectedPlaceName: String?
    @Published var isSearchingLocation: Bool = false
    @Published var isLoadingStops: Bool = false
    @Published var errorMessage: String?

    private let getNearbyStopsUseCase: GetNearbyStopsUseCase
    private let searchCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    private var selectedLocation: Location?

    init(getNearbyStopsUseCase: GetNearbyStopsUseCase) {
        self.getNearbyStopsUseCase = getNearbyStopsUseCase

        super.init()

        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        searchCompleter.region = .saoPauloMetro

        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                self.errorMessage = nil
                if query.isEmpty {
                    self.searchSuggestions = []
                    self.nearbyStops = []
                    self.selectedPlaceName = nil
                    self.selectedLocation = nil
                } else {
                    self.searchCompleter.queryFragment = query
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    func submitSearch() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.region = .saoPauloMetro
        await performSearch(request: request)
    }

    @MainActor
    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: suggestion)
        request.region = .saoPauloMetro
        await performSearch(request: request)
    }

    func distanceToStop(_ stop: Stop) -> Double? {
        guard let selectedLocation else { return nil }
        let origin = CLLocation(latitude: selectedLocation.latitude, longitude: selectedLocation.longitude)
        let destination = CLLocation(latitude: stop.location.latitude, longitude: stop.location.longitude)
        return origin.distance(from: destination)
    }

    @MainActor
    private func performSearch(request: MKLocalSearch.Request) async {
        isSearchingLocation = true
        errorMessage = nil

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let mapItem = response.mapItems.first else {
                errorMessage = "No locations found for that search."
                isSearchingLocation = false
                return
            }

            if !MKCoordinateRegion.saoPauloMetro.contains(mapItem.placemark.coordinate) {
                errorMessage = "Search is limited to the Sao Paulo metro area."
                isSearchingLocation = false
                return
            }

            await applySearchResult(mapItem)
            searchSuggestions = []
        } catch {
            errorMessage = error.localizedDescription
        }

        isSearchingLocation = false
    }

    @MainActor
    private func applySearchResult(_ mapItem: MKMapItem) async {
        let coordinate = mapItem.placemark.coordinate
        let location = Location(latitude: coordinate.latitude, longitude: coordinate.longitude)
        selectedLocation = location
        selectedPlaceName = mapItem.name ?? searchText
//        searchText = mapItem.name ?? searchText

        await loadNearbyStops(for: location)
    }

    @MainActor
    private func loadNearbyStops(for location: Location) async {
        isLoadingStops = true
        errorMessage = nil

        do {
            let stops = try await getNearbyStopsUseCase.execute(limit: 20, location: location)
            nearbyStops = stops
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingStops = false
    }
}

extension SearchViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.searchSuggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
        }
    }
}
