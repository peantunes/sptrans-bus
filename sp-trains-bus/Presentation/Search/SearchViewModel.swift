import Foundation
import Combine
import MapKit

class SearchViewModel: NSObject, ObservableObject {
    @Published var originQuery: String = ""
    @Published var destinationQuery: String = ""
    @Published var originSuggestions: [MKLocalSearchCompletion] = []
    @Published var destinationSuggestions: [MKLocalSearchCompletion] = []
    @Published var alternatives: [TripPlanAlternative] = []
    @Published var isPlanning: Bool = false
    @Published var errorMessage: String?

    private let planTripUseCase: PlanTripUseCase
    private let locationService: LocationServiceProtocol
    private let originCompleter = MKLocalSearchCompleter()
    private let destinationCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()

    private(set) var originLocation: Location?
    private(set) var destinationLocation: Location?

    var rankingPriority: String = "arrives_first"

    init(planTripUseCase: PlanTripUseCase, locationService: LocationServiceProtocol) {
        self.planTripUseCase = planTripUseCase
        self.locationService = locationService

        super.init()

        locationService.requestLocationPermission()

        originCompleter.delegate = self
        destinationCompleter.delegate = self
        originCompleter.resultTypes = [.address, .pointOfInterest]
        destinationCompleter.resultTypes = [.address, .pointOfInterest]
        originCompleter.region = .saoPauloMetro
        destinationCompleter.region = .saoPauloMetro

        setupSearchObservers()
        setOriginToCurrentLocation()
    }

    func setOriginToCurrentLocation() {
        if let location = locationService.getCurrentLocation() {
            originLocation = location
            originQuery = "Current location"
        }
    }

    @MainActor
    func selectOriginSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        await resolveSuggestion(suggestion, isOrigin: true)
    }

    @MainActor
    func selectDestinationSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        await resolveSuggestion(suggestion, isOrigin: false)
    }

    @MainActor
    func planTrip() async {
        errorMessage = nil
        alternatives = []

        guard let originLocation, let destinationLocation else {
            errorMessage = "Select both origin and destination."
            return
        }

        isPlanning = true
        do {
            let plan = try await planTripUseCase.execute(
                origin: originLocation,
                destination: destinationLocation,
                maxAlternatives: 5,
                rankingPriority: rankingPriority
            )
            alternatives = plan.alternatives
        } catch {
            errorMessage = error.localizedDescription
        }
        isPlanning = false
    }

    func clearSuggestions() {
        originSuggestions = []
        destinationSuggestions = []
    }

    private func setupSearchObservers() {
        $originQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                if query.isEmpty || query == "Current location" {
                    self.originSuggestions = []
                    if query.isEmpty {
                        self.originLocation = nil
                    }
                    return
                }
                self.originCompleter.queryFragment = query
            }
            .store(in: &cancellables)

        $destinationQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                if query.isEmpty {
                    self.destinationSuggestions = []
                    self.destinationLocation = nil
                    return
                }
                self.destinationCompleter.queryFragment = query
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func resolveSuggestion(_ suggestion: MKLocalSearchCompletion, isOrigin: Bool) async {
        let request = MKLocalSearch.Request(completion: suggestion)
        request.region = .saoPauloMetro

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let mapItem = response.mapItems.first else { return }

            let location = Location(latitude: mapItem.placemark.coordinate.latitude, longitude: mapItem.placemark.coordinate.longitude)
            let name = mapItem.name ?? suggestion.title

            if isOrigin {
                originLocation = location
                originQuery = name
                originSuggestions = []
            } else {
                destinationLocation = location
                destinationQuery = name
                destinationSuggestions = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension SearchViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            if completer === self.originCompleter {
                self.originSuggestions = completer.results
            } else if completer === self.destinationCompleter {
                self.destinationSuggestions = completer.results
            }
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
        }
    }
}
