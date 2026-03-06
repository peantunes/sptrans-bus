import Foundation

struct WatchSnapshotStore {
    static let appGroupID = "group.com.lolados.sp.due-sp"
    static let snapshotKey = "ios_widget_snapshot_v1"
    static let preferredStopIDKey = "widget_preferred_stop_id_v1"
    static let favoriteRailLineIDsKey = "favorite_rail_line_ids"

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

    func loadPreferredStopID() -> Int? {
        userDefaults.object(forKey: Self.preferredStopIDKey) as? Int
    }

    func loadFavoriteLineIDs() -> Set<String> {
        Set(userDefaults.stringArray(forKey: Self.favoriteRailLineIDsKey) ?? [])
    }
}
