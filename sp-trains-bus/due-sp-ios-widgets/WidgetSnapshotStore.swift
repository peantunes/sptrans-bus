import Foundation

struct WidgetSnapshotStore {
    static let appGroupID = "group.com.lolados.sp.due-sp"
    static let preferredStopIDKey = "widget_preferred_stop_id_v1"
    static let favoriteRailLineIDsKey = "favorite_rail_line_ids"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: Self.appGroupID)) {
        self.userDefaults = userDefaults ?? .standard
    }

    func loadPreferredStopID() -> Int? {
        userDefaults.object(forKey: Self.preferredStopIDKey) as? Int
    }

    func loadFavoriteLineIDs() -> Set<String> {
        Set(userDefaults.stringArray(forKey: Self.favoriteRailLineIDsKey) ?? [])
    }
}
