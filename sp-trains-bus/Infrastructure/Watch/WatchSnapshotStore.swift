import Foundation

final class WatchSnapshotStore: WatchSnapshotSyncing {
    enum Config {
        static let appGroupID = "group.com.lolados.sp.due-sp"
        static let watchSnapshotKey = "watch_transit_snapshot_v1"
        static let iosWidgetSnapshotKey = "ios_widget_snapshot_v1"
        static let preferredStopIDKey = "widget_preferred_stop_id_v1"
    }

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: Config.appGroupID)) {
        self.userDefaults = userDefaults ?? .standard
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func syncRailStatus(lines: [WatchRailLineSnapshot]) {
        var snapshot = loadSnapshot()
        snapshot.generatedAt = Date()
        snapshot.railLines = lines
        save(snapshot)
    }

    func syncNearbyStops(stops: [WatchStopSnapshot]) {
        var snapshot = loadSnapshot()
        snapshot.generatedAt = Date()
        snapshot.nearbyStops = stops
        if loadPreferredStopID() == nil, let firstStop = stops.first {
            syncPreferredStop(stopID: firstStop.stopId)
        }
        save(snapshot)
    }

    func syncArrivals(stopID: Int, arrivals: [WatchArrivalSnapshot]) {
        var snapshot = loadSnapshot()
        snapshot.generatedAt = Date()
        snapshot.arrivalsByStopID["\(stopID)"] = arrivals
        if loadPreferredStopID() == nil {
            syncPreferredStop(stopID: stopID)
        }
        save(snapshot)
    }

    func syncPreferredStop(stopID: Int?) {
        if let stopID {
            userDefaults.set(stopID, forKey: Config.preferredStopIDKey)
        } else {
            userDefaults.removeObject(forKey: Config.preferredStopIDKey)
        }
    }

    func loadSnapshot() -> WatchTransitSnapshot {
        guard let data = userDefaults.data(forKey: Config.watchSnapshotKey) else {
            return .empty
        }
        return (try? decoder.decode(WatchTransitSnapshot.self, from: data)) ?? .empty
    }

    private func loadPreferredStopID() -> Int? {
        userDefaults.object(forKey: Config.preferredStopIDKey) as? Int
    }

    private func save(_ snapshot: WatchTransitSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        userDefaults.set(data, forKey: Config.watchSnapshotKey)
        userDefaults.set(data, forKey: Config.iosWidgetSnapshotKey)
    }
}
