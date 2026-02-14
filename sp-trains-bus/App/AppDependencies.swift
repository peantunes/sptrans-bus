import Foundation
import SwiftData

class AppDependencies {
    let modelContainer: ModelContainer
    let apiClient: APIClient
    let transitRepository: TransitRepositoryProtocol
    let locationService: LocationServiceProtocol
    let storageService: StorageServiceProtocol
    let gtfsFeedService: GTFSFeedServiceProtocol
    let gtfsImportService: GTFSImportServiceProtocol
    let transitDataModeService: TransitDataModeServiceProtocol

    let getNearbyStopsUseCase: GetNearbyStopsUseCase
    let getArrivalsUseCase: GetArrivalsUseCase
    let searchStopsUseCase: SearchStopsUseCase
    let getTripRouteUseCase: GetTripRouteUseCase
    let getRouteShapeUseCase: GetRouteShapeUseCase
    let getMetroStatusUseCase: GetMetroStatusUseCase
    let planTripUseCase: PlanTripUseCase
    let importGTFSDataUseCase: ImportGTFSDataUseCase
    let checkGTFSRefreshUseCase: CheckGTFSRefreshUseCase

    let homeViewModel: HomeViewModel
    let searchViewModel: SearchViewModel
    let systemStatusViewModel: SystemStatusViewModel
    let mapExplorerViewModel: MapExplorerViewModel

    init() {
        modelContainer = LocalDataModelContainer.shared

        // Infrastructure Layer
        apiClient = APIClient()
        let remoteRepository = TransitAPIRepository(apiClient: apiClient)
        let localRepository = LocalTransitRepository(modelContainer: modelContainer)
        locationService = CoreLocationService()
        storageService = SwiftDataStorageService(modelContainer: modelContainer)
        gtfsFeedService = GTFSFeedService(modelContainer: modelContainer)
        gtfsImportService = GTFSImporterService(modelContainer: modelContainer, feedService: gtfsFeedService)
        transitDataModeService = UserDefaultsTransitDataModeService()
        transitRepository = ConfigurableTransitRepository(
            remoteRepository: remoteRepository,
            localRepository: localRepository,
            modeService: transitDataModeService,
            feedService: gtfsFeedService
        )

        // Application Layer - Use Cases
        getNearbyStopsUseCase = GetNearbyStopsUseCase(transitRepository: transitRepository, locationService: locationService)
        getArrivalsUseCase = GetArrivalsUseCase(transitRepository: transitRepository)
        searchStopsUseCase = SearchStopsUseCase(transitRepository: transitRepository)
        getTripRouteUseCase = GetTripRouteUseCase(transitRepository: transitRepository)
        getRouteShapeUseCase = GetRouteShapeUseCase(transitRepository: transitRepository)
        getMetroStatusUseCase = GetMetroStatusUseCase()
        planTripUseCase = PlanTripUseCase(transitRepository: transitRepository)
        importGTFSDataUseCase = ImportGTFSDataUseCase(importService: gtfsImportService, modeService: transitDataModeService)
        checkGTFSRefreshUseCase = CheckGTFSRefreshUseCase(feedService: gtfsFeedService)

        // Presentation Layer - ViewModels
        homeViewModel = HomeViewModel(getNearbyStopsUseCase: getNearbyStopsUseCase, locationService: locationService, storageService: storageService)
        searchViewModel = SearchViewModel(planTripUseCase: planTripUseCase, locationService: locationService)
        systemStatusViewModel = SystemStatusViewModel(apiClient: apiClient, fallbackUseCase: getMetroStatusUseCase)
        mapExplorerViewModel = MapExplorerViewModel(getNearbyStopsUseCase: getNearbyStopsUseCase, locationService: locationService)
    }
}
