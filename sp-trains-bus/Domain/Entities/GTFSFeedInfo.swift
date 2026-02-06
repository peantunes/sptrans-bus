import Foundation

struct GTFSFeedInfo: Codable, Equatable {
    let versionIdentifier: String
    let sourceURL: String?
    let localArchivePath: String?
    let downloadedAt: Date
    let lastCheckedAt: Date
    let etag: String?
    let lastModified: String?
}
