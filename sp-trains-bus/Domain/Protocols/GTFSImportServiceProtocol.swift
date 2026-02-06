import Foundation

protocol GTFSImportServiceProtocol {
    func importFromDirectory(_ directoryURL: URL, sourceURL: String?) async throws -> GTFSFeedInfo
    func hasImportedData() -> Bool
}
