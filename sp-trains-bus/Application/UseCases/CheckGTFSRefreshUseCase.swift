import Foundation

final class CheckGTFSRefreshUseCase {
    private let feedService: GTFSFeedServiceProtocol

    init(feedService: GTFSFeedServiceProtocol) {
        self.feedService = feedService
    }

    func shouldCheckForUpdate(asOf date: Date = Date()) -> Bool {
        feedService.shouldCheckForWeeklyUpdate(asOf: date)
    }

    func markChecked(at date: Date = Date()) {
        feedService.markFeedChecked(at: date)
    }
}
