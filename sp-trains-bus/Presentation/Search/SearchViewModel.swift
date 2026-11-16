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
    @Published private(set) var originIsCurrentLocation = false
    @Published private(set) var alternatives: [TripPlanAlternative] = []
    @Published private(set) var resultContext: JourneySearchContext?
    @Published private(set) var isPlanning = false
    @Published private(set) var isResolving = false
    @Published var errorMessage: String?
    @Published var rankingPriority = "arrives_first" { didSet { if rankingPriority != oldValue { invalidateResults(); persistForm() } } }
    @Published var maxTransfers = 3 { didSet { if maxTransfers != oldValue { invalidateResults(); persistForm() } } }
    /// Premium only. When false, searches leave at the moment the button is pressed.
    @Published private(set) var useDepartureTime = false
    @Published var departureDate = Date() { didSet { if useDepartureTime { invalidateResults() } } }
    @Published private(set) var hasPlanned = false
    @Published private(set) var savedRoutes: [SavedRoute] = []
    @Published private(set) var searchesToday = 0
    @Published var premiumPrompt: PlannerPremiumPrompt?

    private let planTripUseCase: PlanTripUseCase
    private let locationService: LocationServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let storage: PlannerStorage
    private let isPremiumProvider: () -> Bool
    private let now: () -> Date
    private let originCompleter = MKLocalSearchCompleter()
    private let destinationCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    private var settingSelection = false
    private var revision = UUID()
    private var resolutionID = UUID()

    var canPlan: Bool { originLocation != nil && destinationLocation != nil && !isPlanning && !isResolving }
    var isPremium: Bool { isPremiumProvider() }

    /// Remaining free searches today; nil for Premium.
    var searchesLeft: Int? {
        isPremium ? nil : max(0, PlannerLimits.freeDailySearches - searchesToday)
    }

    var hasFormContent: Bool {
        !originQuery.isEmpty || !destinationQuery.isEmpty || useDepartureTime
    }

    var currentRouteIsSaved: Bool {
        guard let originLocation, let destinationLocation else { return false }
        return savedRoutes.contains { route in
            let sameOrigin = route.originIsCurrentLocation
                ? originIsCurrentLocation
                : !originIsCurrentLocation && route.origin.location == originLocation
            return sameOrigin && route.destination.location == destinationLocation
        }
    }

    var canSaveCurrentRoute: Bool { originLocation != nil && destinationLocation != nil && !currentRouteIsSaved }

    init(planTripUseCase: PlanTripUseCase, locationService: LocationServiceProtocol,
         analyticsService: AnalyticsServiceProtocol? = nil,
         storage: PlannerStorage = InMemoryPlannerStore(),
         isPremium: @escaping () -> Bool = { false },
         now: @escaping () -> Date = Date.init) {
        self.planTripUseCase = planTripUseCase
        self.locationService = locationService
        self.analyticsService = analyticsService ?? NoOpAnalyticsService()
        self.storage = storage
        self.isPremiumProvider = isPremium
        self.now = now
        super.init()
        originCompleter.delegate = self
        destinationCompleter.delegate = self
        for completer in [originCompleter, destinationCompleter] {
            completer.resultTypes = [.address, .pointOfInterest]
            completer.region = .saoPauloMetro
        }
        setupSearchObservers()
        savedRoutes = storage.savedRoutes()
        searchesToday = storage.searches(on: Self.dayKey(now()))
        restoreLastForm()
        fillOriginWithCurrentLocationIfEmpty()
    }

    /// The view model is created at app launch, usually before a location fix exists.
    /// Fill an untouched origin with the current location once one is available; also
    /// refreshes counts that may have changed (a new day, Premium bought elsewhere).
    func fillOriginWithCurrentLocationIfEmpty() {
        searchesToday = storage.searches(on: Self.dayKey(now()))
        guard originLocation == nil,
              originQuery.trimmingCharacters(in: .whitespaces).isEmpty,
              let location = locationService.getCurrentLocation() else { return }
        selectPlace(location, name: Self.currentLocationLabel, isOrigin: true, isCurrentLocation: true)
    }

    func setOriginToCurrentLocation() {
        locationService.requestLocationPermission()
        guard let location = locationService.getCurrentLocation() else {
            errorMessage = NSLocalizedString("Location unavailable. Choose an origin or allow location access.", comment: "")
            return
        }
        selectPlace(location, name: Self.currentLocationLabel, isOrigin: true, isCurrentLocation: true)
    }

    func selectPlace(_ location: Location, name: String, isOrigin: Bool, isCurrentLocation: Bool = false) {
        settingSelection = true
        if isOrigin {
            originQuery = name
            originLocation = location
            originIsCurrentLocation = isCurrentLocation
        } else {
            destinationQuery = name
            destinationLocation = location
        }
        settingSelection = false
        clearSuggestions()
        invalidateResults()
        persistForm()
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
        originIsCurrentLocation = false
        settingSelection = false
        clearSuggestions()
        invalidateResults()
        persistForm()
    }

    /// Clears one field.
    func clearField(isOrigin: Bool) {
        if isOrigin { originQuery = "" } else { destinationQuery = "" }
        persistForm()
    }

    /// Clears the whole form (places and time); preferences are kept.
    func clearForm() {
        originQuery = ""
        destinationQuery = ""
        useDepartureTime = false
        departureDate = now()
        clearSuggestions()
        invalidateResults()
        persistForm()
    }

    func departNow() {
        useDepartureTime = false
        departureDate = now()
        invalidateResults()
    }

    /// Choosing a departure time is Premium; returns whether the picker may show.
    @discardableResult
    func chooseDepartureTime() -> Bool {
        guard isPremium else {
            premiumPrompt = .chooseTime
            return false
        }
        if !useDepartureTime {
            useDepartureTime = true
            departureDate = now()
        }
        invalidateResults()
        return true
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
        let premium = isPremium
        let pressedAt = now()
        searchesToday = storage.searches(on: Self.dayKey(pressedAt))
        if !premium && searchesToday >= PlannerLimits.freeDailySearches {
            premiumPrompt = .searchLimit
            return
        }
        invalidateResults()
        let requestID = revision
        // "Now" is the moment the button is pressed, sent explicitly. A chosen time is Premium only.
        let departure = premium && useDepartureTime ? departureDate : pressedAt
        let context = JourneySearchContext(origin: originLocation, destination: destinationLocation,
            originLabel: originQuery, destinationLabel: destinationQuery, departure: departure)
        let options = TripPlanningOptions(departure: departure, maxTransfers: maxTransfers)
        isPlanning = true
        clearSuggestions()
        defer { isPlanning = false }
        analyticsService.trackEvent(name: "search_plan_trip_requested", properties: ["ranking_priority": rankingPriority])
        do {
            let plan = try await planTripUseCase.execute(origin: context.origin, destination: context.destination,
                maxAlternatives: 5, rankingPriority: rankingPriority, options: options)
            // Only successful searches count towards the free limit.
            searchesToday = storage.recordSearch(on: Self.dayKey(pressedAt))
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

    // MARK: - Saved routes

    func saveCurrentRoute() {
        guard let originLocation, let destinationLocation, !currentRouteIsSaved else { return }
        guard isPremium || savedRoutes.count < PlannerLimits.freeSavedRoutes else {
            premiumPrompt = .saveLimit
            return
        }
        let route = SavedRoute(
            id: UUID().uuidString,
            origin: PlannerPlace(name: originQuery, location: originLocation),
            destination: PlannerPlace(name: destinationQuery, location: destinationLocation),
            originIsCurrentLocation: originIsCurrentLocation
        )
        savedRoutes.append(route)
        storage.setSavedRoutes(savedRoutes)
        analyticsService.trackEvent(name: "search_route_saved", properties: ["count": "\(savedRoutes.count)"])
    }

    func deleteRoute(_ route: SavedRoute) {
        savedRoutes.removeAll { $0.id == route.id }
        storage.setSavedRoutes(savedRoutes)
    }

    /// Fills the form with a saved route and searches it now.
    func useRoute(_ route: SavedRoute) async {
        if route.originIsCurrentLocation {
            locationService.requestLocationPermission()
            guard let here = locationService.getCurrentLocation() else {
                errorMessage = NSLocalizedString("Location unavailable. Choose an origin or allow location access.", comment: "")
                return
            }
            selectPlace(here, name: Self.currentLocationLabel, isOrigin: true, isCurrentLocation: true)
        } else {
            selectPlace(route.origin.location, name: route.origin.name, isOrigin: true)
        }
        selectPlace(route.destination.location, name: route.destination.name, isOrigin: false)
        useDepartureTime = false
        await planTrip()
    }

    // MARK: - Remembered form

    private func restoreLastForm() {
        guard let form = storage.lastForm() else { return }
        settingSelection = true
        // A "current location" origin is resolved again where the user is now.
        if let origin = form.origin, !form.originIsCurrentLocation {
            originQuery = origin.name
            originLocation = origin.location
        }
        if let destination = form.destination {
            destinationQuery = destination.name
            destinationLocation = destination.location
        }
        settingSelection = false
        rankingPriority = form.rankingPriority
        maxTransfers = min(4, max(0, form.maxTransfers))
    }

    private func persistForm() {
        storage.saveForm(PlanFormSnapshot(
            origin: originIsCurrentLocation ? nil : originLocation.map { PlannerPlace(name: originQuery, location: $0) },
            originIsCurrentLocation: originIsCurrentLocation && originLocation != nil,
            destination: destinationLocation.map { PlannerPlace(name: destinationQuery, location: $0) },
            rankingPriority: rankingPriority,
            maxTransfers: maxTransfers
        ))
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
        if isOrigin { originLocation = nil; originIsCurrentLocation = false; originSuggestions = [] }
        else { destinationLocation = nil; destinationSuggestions = [] }
        invalidateResults()
        persistForm()
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

    static let currentLocationLabel = NSLocalizedString("Current location", comment: "")

    /// São Paulo calendar day for the daily search count.
    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
