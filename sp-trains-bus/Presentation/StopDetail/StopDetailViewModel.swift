import Foundation
import Combine

class StopDetailViewModel: ObservableObject {
    @Published var stop: Stop
    @Published var arrivals: [Arrival] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isFavorite: Bool = false
    @Published var selectedArrival: Arrival?
    @Published var journeyStops: [Stop] = []
    @Published var journeyShape: [Location] = []
    @Published var isLoadingJourney: Bool = false
    @Published var journeyErrorMessage: String?

    private let getArrivalsUseCase: GetArrivalsUseCase
    private let getTripRouteUseCase: GetTripRouteUseCase
    private let getRouteShapeUseCase: GetRouteShapeUseCase
    private let storageService: StorageServiceProtocol
    private var timer: Timer?

    init(
        stop: Stop,
        getArrivalsUseCase: GetArrivalsUseCase,
        getTripRouteUseCase: GetTripRouteUseCase,
        getRouteShapeUseCase: GetRouteShapeUseCase,
        storageService: StorageServiceProtocol
    ) {
        self.stop = stop
        self.getArrivalsUseCase = getArrivalsUseCase
        self.getTripRouteUseCase = getTripRouteUseCase
        self.getRouteShapeUseCase = getRouteShapeUseCase
        self.storageService = storageService
        self.isFavorite = storageService.isFavorite(stopId: stop.stopId)
    }

    func loadArrivals() {
        isLoading = true
        errorMessage = nil

        Task {
            await fetchArrivals()
        }
    }

    @MainActor
    func refreshArrivals() async {
        isLoading = true
        errorMessage = nil
        await fetchArrivals()
    }

    @MainActor
    private func fetchArrivals() async {
        do {
            let fetchedArrivals = try await getArrivalsUseCase.execute(stopId: stop.stopId, limit: 10)
            self.arrivals = fetchedArrivals
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func toggleFavorite() {
        if isFavorite {
            storageService.removeFavorite(stop: stop)
        } else {
            storageService.saveFavorite(stop: stop)
        }
        isFavorite.toggle()
    }

    func startRefreshingArrivals() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.loadArrivals()
        }
    }

    func stopRefreshingArrivals() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    func selectArrival(_ arrival: Arrival) {
        selectedArrival = arrival
        journeyStops = []
        journeyShape = []
        journeyErrorMessage = nil
        isLoadingJourney = true

        Task {
            await loadJourney(for: arrival)
        }
    }

    @MainActor
    func clearJourneySelection() {
        selectedArrival = nil
        journeyStops = []
        journeyShape = []
        journeyErrorMessage = nil
        isLoadingJourney = false
    }

    @MainActor
    private func loadJourney(for arrival: Arrival) async {
        do {
            let tripStop = try await getTripRouteUseCase.execute(tripId: arrival.tripId)
            let shape: [Location]
            if tripStop.trip.shapeId.isEmpty {
                shape = []
            } else {
                shape = (try? await getRouteShapeUseCase.execute(shapeId: tripStop.trip.shapeId)) ?? []
            }
            journeyStops = tripStop.stops.sorted { $0.stopSequence < $1.stopSequence }
            journeyShape = shape
            journeyErrorMessage = nil
            isLoadingJourney = false
        } catch {
            journeyErrorMessage = error.localizedDescription
            isLoadingJourney = false
        }
    }
}
