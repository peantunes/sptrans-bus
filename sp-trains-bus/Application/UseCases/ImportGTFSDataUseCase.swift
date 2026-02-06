import Foundation

final class ImportGTFSDataUseCase {
    private let importService: GTFSImportServiceProtocol
    private let modeService: TransitDataModeServiceProtocol

    init(importService: GTFSImportServiceProtocol, modeService: TransitDataModeServiceProtocol) {
        self.importService = importService
        self.modeService = modeService
    }

    func execute(from directoryURL: URL, sourceURL: String?) async throws -> GTFSFeedInfo {
        let importedFeed = try await importService.importFromDirectory(directoryURL, sourceURL: sourceURL)
        modeService.useLocalData = true
        return importedFeed
    }
}
