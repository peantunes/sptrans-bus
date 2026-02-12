import Foundation
import Combine

@MainActor
final class LocalDataSettingsViewModel: ObservableObject {
    @Published var useLocalData: Bool
    @Published var currentFeed: GTFSFeedInfo?
    @Published var shouldCheckForUpdates: Bool = false
    @Published var isImporting: Bool = false
    @Published var importSuccessMessage: String?
    @Published var errorMessage: String?
    @Published var savedPlaces: [UserPlace] = []

    private let modeService: TransitDataModeServiceProtocol
    private let feedService: GTFSFeedServiceProtocol
    private let importUseCase: ImportGTFSDataUseCase
    private let checkRefreshUseCase: CheckGTFSRefreshUseCase
    private let storageService: StorageServiceProtocol
    private let featureToggles: FeatureToggles.Type

    init(
        modeService: TransitDataModeServiceProtocol,
        feedService: GTFSFeedServiceProtocol,
        importUseCase: ImportGTFSDataUseCase,
        checkRefreshUseCase: CheckGTFSRefreshUseCase,
        storageService: StorageServiceProtocol,
        featureToggles: FeatureToggles.Type = FeatureToggles.self
    ) {
        self.modeService = modeService
        self.feedService = feedService
        self.importUseCase = importUseCase
        self.checkRefreshUseCase = checkRefreshUseCase
        self.storageService = storageService
        self.featureToggles = featureToggles
        self.useLocalData = modeService.useLocalData
        self.currentFeed = feedService.getCurrentFeed()
        refreshStatus()
    }

    func refreshStatus() {
        useLocalData = modeService.useLocalData
        currentFeed = feedService.getCurrentFeed()
        shouldCheckForUpdates = checkRefreshUseCase.shouldCheckForUpdate()
        savedPlaces = storageService.getSavedPlaces()
    }

    func setLocalDataEnabled(_ enabled: Bool) {
        modeService.useLocalData = enabled
        useLocalData = enabled
    }

    func importGTFSSource(_ sourceURL: URL) async {
        isImporting = true
        importSuccessMessage = nil
        errorMessage = nil

        do {
            let feed = try await importUseCase.execute(
                from: sourceURL,
                feedSourceURL: sourceURL.absoluteString
            )
            importSuccessMessage = "Imported local feed \(feed.versionIdentifier)."
            refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }

        isImporting = false
    }

    func markUpdateCheckNow() {
        checkRefreshUseCase.markChecked()
        refreshStatus()
    }

    func clearMessages() {
        importSuccessMessage = nil
        errorMessage = nil
    }

    var placeSummary: String {
        var parts: [String] = []

        if featureToggles.isHomeWorkLocationsEnabled {
            let homeCount = savedPlaces.filter { $0.type == .home }.count
            let workCount = savedPlaces.filter { $0.type == .work }.count
            parts.append("Home \(homeCount)")
            parts.append("Work \(workCount)")
        }

        let studyCount = savedPlaces.filter { $0.type == .study }.count
        let customCount = savedPlaces.filter { $0.type == .custom }.count
        parts.append("Study \(studyCount)")
        parts.append("Custom \(customCount)")
        return parts.joined(separator: " | ")
    }

    var visiblePlacesCount: Int {
        savedPlaces.filter { featureToggles.isUserPlaceTypeEnabled($0.type) }.count
    }
}
