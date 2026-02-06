import Foundation
import SwiftData

class AppDependencies {
    let modelContainer: ModelContainer
    let apiClient: APIClient
    let transitRepository: TransitRepositoryProtocol
    let locationService: LocationServiceProtocol
    let storageService: StorageServiceProtocol
    let gtfsFeedService: GTFSFeedServiceProtocol

    let getNearbyStopsUseCase: GetNearbyStopsUseCase
    let getArrivalsUseCase: GetArrivalsUseCase
    let searchStopsUseCase: SearchStopsUseCase
    let getTripRouteUseCase: GetTripRouteUseCase
    let getRouteShapeUseCase: GetRouteShapeUseCase
    let getMetroStatusUseCase: GetMetroStatusUseCase
    let planTripUseCase: PlanTripUseCase

    let homeViewModel: HomeViewModel
    let searchViewModel: SearchViewModel
    let systemStatusViewModel: SystemStatusViewModel
    let mapExplorerViewModel: MapExplorerViewModel

    init() {
        modelContainer = LocalDataModelContainer.shared

        // Infrastructure Layer
        apiClient = APIClient()
        transitRepository = TransitAPIRepository(apiClient: apiClient)
        locationService = CoreLocationService()
        storageService = SwiftDataStorageService(modelContainer: modelContainer)
        gtfsFeedService = GTFSFeedService(modelContainer: modelContainer)

        // Application Layer - Use Cases
        getNearbyStopsUseCase = GetNearbyStopsUseCase(transitRepository: transitRepository, locationService: locationService)
        getArrivalsUseCase = GetArrivalsUseCase(transitRepository: transitRepository)
        searchStopsUseCase = SearchStopsUseCase(transitRepository: transitRepository)
        getTripRouteUseCase = GetTripRouteUseCase(transitRepository: transitRepository)
        getRouteShapeUseCase = GetRouteShapeUseCase(transitRepository: transitRepository)
        getMetroStatusUseCase = GetMetroStatusUseCase()
        planTripUseCase = PlanTripUseCase(transitRepository: transitRepository)

        // Presentation Layer - ViewModels
        homeViewModel = HomeViewModel(getNearbyStopsUseCase: getNearbyStopsUseCase, locationService: locationService, storageService: storageService)
        searchViewModel = SearchViewModel(planTripUseCase: planTripUseCase, locationService: locationService)
        systemStatusViewModel = SystemStatusViewModel(getMetroStatusUseCase: getMetroStatusUseCase)
        mapExplorerViewModel = MapExplorerViewModel(getNearbyStopsUseCase: getNearbyStopsUseCase, locationService: locationService)
    }
}
