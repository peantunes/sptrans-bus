import Foundation

struct WatchSnapshotStore {
    static let appGroupID = "group.com.lolados.sp.due-sp"
    static let snapshotKey = "watch_transit_snapshot_v1"

    private let userDefaults: UserDefaults
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: Self.appGroupID)) {
        self.userDefaults = userDefaults ?? .standard
    }

    func loadSnapshot() -> WatchTransitSnapshot {
        guard let data = userDefaults.data(forKey: Self.snapshotKey) else {
            return .empty
        }
        return (try? decoder.decode(WatchTransitSnapshot.self, from: data)) ?? .empty
    }
}
