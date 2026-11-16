import Foundation
import Combine
import MapKit

struct JourneySearchContext {
    let origin: Location
    let destination: Location
    let originLabel: String
    let destinationLabel: String
    let departure: Date
}

@MainActor
class SearchViewModel: NSObject, ObservableObject {
    // TextField writes the same text back (e.g. when focus moves); only a real edit
    // may discard the selected place.
    @Published var originQuery = "" { didSet { if originQuery != oldValue { queryChanged(isOrigin: true) } } }
    @Published var destinationQuery = "" { didSet { if destinationQuery != oldValue { queryChanged(isOrigin: false) } } }
    @Published var originSuggestions: [MKLocalSearchCompletion] = []
    @Published var destinationSuggestions: [MKLocalSearchCompletion] = []
    @Published private(set) var originLocation: Location?
    @Published private(set) var destinationLocation: Location?
    @Published private(set) var alternatives: [TripPlanAlternative] = []
    @Published private(set) var resultContext: JourneySearchContext?
    @Published private(set) var isPlanning = false
    @Published private(set) var isResolving = false
    @Published var errorMessage: String?
    @Published var rankingPriority = "arrives_first"
    @Published var maxTransfers = 3
    @Published var useDepartureTime = false
    @Published var departureDate = Date()
    @Published private(set) var hasPlanned = false

    private let planTripUseCase: PlanTripUseCase
    private let locationService: LocationServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let originCompleter = MKLocalSearchCompleter()
    private let destinationCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    private var settingSelection = false
    private var revision = UUID()
    private var resolutionID = UUID()

    var canPlan: Bool { originLocation != nil && destinationLocation != nil && !isPlanning && !isResolving }

    init(planTripUseCase: PlanTripUseCase, locationService: LocationServiceProtocol,
         analyticsService: AnalyticsServiceProtocol? = nil) {
        self.planTripUseCase = planTripUseCase
        self.locationService = locationService
        self.analyticsService = analyticsService ?? NoOpAnalyticsService()
        super.init()
        originCompleter.delegate = self
        destinationCompleter.delegate = self
        for completer in [originCompleter, destinationCompleter] {
            completer.resultTypes = [.address, .pointOfInterest]
            completer.region = .saoPauloMetro
        }
        setupSearchObservers()
        if let location = locationService.getCurrentLocation() {
            selectPlace(location, name: NSLocalizedString("Current location", comment: ""), isOrigin: true)
        }
    }

    /// The view model is created at app launch, usually before a location fix exists.
    /// Fill an untouched origin with the current location once one is available.
    func fillOriginWithCurrentLocationIfEmpty() {
        guard originLocation == nil,
              originQuery.trimmingCharacters(in: .whitespaces).isEmpty,
              let location = locationService.getCurrentLocation() else { return }
        selectPlace(location, name: NSLocalizedString("Current location", comment: ""), isOrigin: true)
    }

    func setOriginToCurrentLocation() {
        locationService.requestLocationPermission()
        guard let location = locationService.getCurrentLocation() else {
            errorMessage = NSLocalizedString("Location unavailable. Choose an origin or allow location access.", comment: "")
            return
        }
        selectPlace(location, name: NSLocalizedString("Current location", comment: ""), isOrigin: true)
    }

    func selectPlace(_ location: Location, name: String, isOrigin: Bool) {
        settingSelection = true
        if isOrigin {
            originQuery = name
            originLocation = location
        } else {
            destinationQuery = name
            destinationLocation = location
        }
        settingSelection = false
        clearSuggestions()
        invalidateResults()
    }

    func swapLocations() {
        resolutionID = UUID()
        isResolving = false
        settingSelection = true
        let query = originQuery
        let location = originLocation
        originQuery = destinationQuery
        originLocation = destinationLocation
        destinationQuery = query
        destinationLocation = location
        settingSelection = false
        clearSuggestions()
        invalidateResults()
    }

    func departNow() {
        useDepartureTime = false
        departureDate = Date()
        invalidateResults()
    }

    func invalidateResults() {
        revision = UUID()
        alternatives = []
        resultContext = nil
        hasPlanned = false
        errorMessage = nil
    }

    func selectOriginSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        await resolveSuggestion(suggestion, isOrigin: true)
    }

    func selectDestinationSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        await resolveSuggestion(suggestion, isOrigin: false)
    }

    func planTrip() async {
        guard !isPlanning else { return }
        guard let originLocation, let destinationLocation, !isResolving else {
            errorMessage = NSLocalizedString("Select both origin and destination.", comment: "")
            return
        }
        invalidateResults()
        let requestID = revision
        let context = JourneySearchContext(origin: originLocation, destination: destinationLocation,
            originLabel: originQuery, destinationLabel: destinationQuery,
            departure: useDepartureTime ? departureDate : Date())
        let options = TripPlanningOptions(departure: useDepartureTime ? departureDate : nil, maxTransfers: maxTransfers)
        isPlanning = true
        clearSuggestions()
        defer { isPlanning = false }
        analyticsService.trackEvent(name: "search_plan_trip_requested", properties: ["ranking_priority": rankingPriority])
        do {
            let plan = try await planTripUseCase.execute(origin: context.origin, destination: context.destination,
                maxAlternatives: 5, rankingPriority: rankingPriority, options: options)
            guard requestID == revision, !Task.isCancelled else { return }
            alternatives = plan.alternatives + [plan.walkingAlternative].compactMap { $0 }
            resultContext = context
            hasPlanned = true
            analyticsService.trackEvent(name: "search_plan_trip_succeeded", properties: ["alternatives_count": "\(alternatives.count)"])
        } catch is CancellationError {
            // A cancelled search must not replace newer input or show an error.
        } catch {
            guard requestID == revision else { return }
            errorMessage = error.localizedDescription
        }
    }

    func clearSuggestions() {
        originCompleter.cancel()
        destinationCompleter.cancel()
        originSuggestions = []
        destinationSuggestions = []
    }

    private func queryChanged(isOrigin: Bool) {
        guard !settingSelection else { return }
        resolutionID = UUID()
        isResolving = false
        if isOrigin { originLocation = nil; originSuggestions = [] }
        else { destinationLocation = nil; destinationSuggestions = [] }
        invalidateResults()
    }

    private func setupSearchObservers() {
        $originQuery.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates().sink { [weak self] query in
                guard let self, self.originLocation == nil, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                self.originCompleter.queryFragment = query
            }.store(in: &cancellables)
        $destinationQuery.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates().sink { [weak self] query in
                guard let self, self.destinationLocation == nil, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                self.destinationCompleter.queryFragment = query
            }.store(in: &cancellables)
    }

    private func resolveSuggestion(_ suggestion: MKLocalSearchCompletion, isOrigin: Bool) async {
        let token = UUID()
        resolutionID = token
        isResolving = true
        let request = MKLocalSearch.Request(completion: suggestion)
        request.region = .saoPauloMetro
        defer { if resolutionID == token { isResolving = false } }
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard token == resolutionID, !Task.isCancelled, let item = response.mapItems.first else { return }
            selectPlace(Location(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude),
                        name: item.name ?? suggestion.title, isOrigin: isOrigin)
        } catch {
            guard token == resolutionID else { return }
            errorMessage = error.localizedDescription
        }
    }
}

extension SearchViewModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            if completer === originCompleter, originLocation == nil, !originQuery.isEmpty {
                originSuggestions = completer.results
            } else if completer === destinationCompleter, destinationLocation == nil, !destinationQuery.isEmpty {
                destinationSuggestions = completer.results
            }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            guard (completer === originCompleter && originLocation == nil) ||
                  (completer === destinationCompleter && destinationLocation == nil) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
