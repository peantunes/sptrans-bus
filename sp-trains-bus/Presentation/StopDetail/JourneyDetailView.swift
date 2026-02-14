import SwiftUI

struct JourneyDetailView: View {
    @ObservedObject var viewModel: StopDetailViewModel

    var body: some View {
        JourneySection(
            selection: viewModel.selectedArrival,
            stops: viewModel.journeyStops,
            shape: viewModel.journeyShape,
            isLoading: viewModel.isLoadingJourney,
            errorMessage: viewModel.journeyErrorMessage,
            currentStopId: viewModel.stop.stopId,
            onClear: viewModel.clearJourneySelection,
            onRetry: {
                if let selectedArrival = viewModel.selectedArrival {
                    viewModel.selectArrival(selectedArrival)
                }
            }
        )
        .padding(.horizontal)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(localized("stop_detail.journey.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

#Preview {
    class MockTransitRepository: TransitRepositoryProtocol {
        func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] { [] }
        func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] { [] }
        func searchStops(query: String, limit: Int) async throws -> [Stop] { [] }
        func getTrip(tripId: String) async throws -> TripStop { fatalError() }
        func getRoute(routeId: String) async throws -> Route { fatalError() }
        func getShape(shapeId: String) async throws -> [Location] { [] }
        func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] { [] }
        func planTrip(origin: Location, destination: Location, maxAlternatives: Int, rankingPriority: String) async throws -> TripPlan {
            TripPlan(alternatives: [], rankingPriority: rankingPriority)
        }
    }

    class MockStorageService: StorageServiceProtocol {
        func saveFavorite(stop: Stop) {}
        func removeFavorite(stop: Stop) {}
        func isFavorite(stopId: Int) -> Bool { false }
        func getFavoriteStops() -> [Stop] { [] }
        func savePlace(_ place: UserPlace) {}
        func removePlace(id: UUID) {}
        func getSavedPlaces() -> [UserPlace] { [] }
        func getPlaces(type: UserPlaceType) -> [UserPlace] { [] }
        func saveHome(location: Location) {}
        func getHomeLocation() -> Location? { nil }
        func saveWork(location: Location) {}
        func getWorkLocation() -> Location? { nil }
    }

    let stop = Stop(stopId: 18848, stopName: "Clínicas", location: Location(latitude: -23.554022, longitude: -46.671108), stopSequence: 0, routes: "METRÔ", stopCode: "CLI001", wheelchairBoarding: 0)
    let repository = MockTransitRepository()
    let viewModel = StopDetailViewModel(
        stop: stop,
        getArrivalsUseCase: GetArrivalsUseCase(transitRepository: repository),
        getTripRouteUseCase: GetTripRouteUseCase(transitRepository: repository),
        getRouteShapeUseCase: GetRouteShapeUseCase(transitRepository: repository),
        storageService: MockStorageService()
    )

    return NavigationStack {
        JourneyDetailView(viewModel: viewModel)
    }
}
