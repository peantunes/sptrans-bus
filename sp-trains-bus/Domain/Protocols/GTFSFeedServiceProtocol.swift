import Foundation

protocol GTFSFeedServiceProtocol {
    func getCurrentFeed() -> GTFSFeedInfo?
    func updateFeed(_ feed: GTFSFeedInfo)
    func shouldCheckForWeeklyUpdate(asOf date: Date) -> Bool
    func markFeedChecked(at date: Date)
}
