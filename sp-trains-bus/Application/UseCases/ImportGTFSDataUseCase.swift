import Foundation

final class ImportGTFSDataUseCase {
    private let importService: GTFSImportServiceProtocol
    private let modeService: TransitDataModeServiceProtocol
    private let archivePreparationService: GTFSArchivePreparationServiceProtocol
    private let fileManager: FileManager

    init(
        importService: GTFSImportServiceProtocol,
        modeService: TransitDataModeServiceProtocol,
        archivePreparationService: GTFSArchivePreparationServiceProtocol = GTFSArchivePreparationService(),
        fileManager: FileManager = .default
    ) {
        self.importService = importService
        self.modeService = modeService
        self.archivePreparationService = archivePreparationService
        self.fileManager = fileManager
    }

    func execute(from sourceURL: URL, feedSourceURL: String?) async throws -> GTFSFeedInfo {
        let preparedImport = try archivePreparationService.prepareImportDirectory(from: sourceURL)
        defer {
            if let cleanupURL = preparedImport.cleanupURL {
                try? fileManager.removeItem(at: cleanupURL)
            }
        }

        let resolvedSource = feedSourceURL ?? sourceURL.absoluteString
        let importedFeed = try await importService.importFromDirectory(
            preparedImport.directoryURL,
            sourceURL: resolvedSource
        )
        modeService.useLocalData = true
        return importedFeed
    }
}
