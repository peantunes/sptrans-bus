import Foundation
import SwiftData

class GTFSFeedService: GTFSFeedServiceProtocol {
    private let modelContainer: ModelContainer
    private let calendar: Calendar

    init(modelContainer: ModelContainer, calendar: Calendar = .current) {
        self.modelContainer = modelContainer
        self.calendar = calendar
    }

    func getCurrentFeed() -> GTFSFeedInfo? {
        let context = ModelContext(modelContainer)

        do {
            let descriptor = FetchDescriptor<GTFSFeedMetadataModel>(
                predicate: #Predicate { model in
                    model.id == "primary"
                }
            )

            guard let model = try context.fetch(descriptor).first else {
                return nil
            }

            return GTFSFeedInfo(
                versionIdentifier: model.versionIdentifier,
                sourceURL: model.sourceURL,
                localArchivePath: model.localArchivePath,
                downloadedAt: model.downloadedAt,
                lastCheckedAt: model.lastCheckedAt,
                etag: model.etag,
                lastModified: model.lastModified
            )
        } catch {
            print("getCurrentFeed failed: \(error.localizedDescription)")
            return nil
        }
    }

    func updateFeed(_ feed: GTFSFeedInfo) {
        let context = ModelContext(modelContainer)

        do {
            let descriptor = FetchDescriptor<GTFSFeedMetadataModel>(
                predicate: #Predicate { model in
                    model.id == "primary"
                }
            )

            if let existing = try context.fetch(descriptor).first {
                existing.versionIdentifier = feed.versionIdentifier
                existing.sourceURL = feed.sourceURL
                existing.localArchivePath = feed.localArchivePath
                existing.downloadedAt = feed.downloadedAt
                existing.lastCheckedAt = feed.lastCheckedAt
                existing.etag = feed.etag
                existing.lastModified = feed.lastModified
            } else {
                context.insert(
                    GTFSFeedMetadataModel(
                        versionIdentifier: feed.versionIdentifier,
                        sourceURL: feed.sourceURL,
                        localArchivePath: feed.localArchivePath,
                        downloadedAt: feed.downloadedAt,
                        lastCheckedAt: feed.lastCheckedAt,
                        etag: feed.etag,
                        lastModified: feed.lastModified
                    )
                )
            }

            try context.save()
        } catch {
            print("updateFeed failed: \(error.localizedDescription)")
        }
    }

    func shouldCheckForWeeklyUpdate(asOf date: Date = Date()) -> Bool {
        guard let currentFeed = getCurrentFeed() else {
            return true
        }

        guard let nextAllowedCheck = calendar.date(byAdding: .day, value: 7, to: currentFeed.lastCheckedAt) else {
            return true
        }

        return date >= nextAllowedCheck
    }

    func markFeedChecked(at date: Date = Date()) {
        guard let currentFeed = getCurrentFeed() else {
            let bootstrapFeed = GTFSFeedInfo(
                versionIdentifier: "unknown",
                sourceURL: nil,
                localArchivePath: nil,
                downloadedAt: date,
                lastCheckedAt: date,
                etag: nil,
                lastModified: nil
            )
            updateFeed(bootstrapFeed)
            return
        }

        updateFeed(
            GTFSFeedInfo(
                versionIdentifier: currentFeed.versionIdentifier,
                sourceURL: currentFeed.sourceURL,
                localArchivePath: currentFeed.localArchivePath,
                downloadedAt: currentFeed.downloadedAt,
                lastCheckedAt: date,
                etag: currentFeed.etag,
                lastModified: currentFeed.lastModified
            )
        )
    }
}
