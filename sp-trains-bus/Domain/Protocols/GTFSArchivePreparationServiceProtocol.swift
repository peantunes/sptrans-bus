import Foundation

struct GTFSPreparedImportDirectory {
    let directoryURL: URL
    let cleanupURL: URL?
}

protocol GTFSArchivePreparationServiceProtocol {
    func prepareImportDirectory(from sourceURL: URL) throws -> GTFSPreparedImportDirectory
}
