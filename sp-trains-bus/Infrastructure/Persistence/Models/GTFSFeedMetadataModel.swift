import Foundation
import SwiftData

@Model
final class GTFSFeedMetadataModel {
    @Attribute(.unique) var id: String
    var versionIdentifier: String
    var sourceURL: String?
    var localArchivePath: String?
    var downloadedAt: Date
    var lastCheckedAt: Date
    var etag: String?
    var lastModified: String?

    init(
        id: String = "primary",
        versionIdentifier: String,
        sourceURL: String?,
        localArchivePath: String?,
        downloadedAt: Date,
        lastCheckedAt: Date,
        etag: String?,
        lastModified: String?
    ) {
        self.id = id
        self.versionIdentifier = versionIdentifier
        self.sourceURL = sourceURL
        self.localArchivePath = localArchivePath
        self.downloadedAt = downloadedAt
        self.lastCheckedAt = lastCheckedAt
        self.etag = etag
        self.lastModified = lastModified
    }
}
