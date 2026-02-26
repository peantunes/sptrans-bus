import Foundation

final class WatchSnapshotStore: WatchSnapshotSyncing {
    enum Config {
        static let appGroupID = "group.com.lolados.sp.due-sp"
        static let snapshotKey = "watch_transit_snapshot_v1"
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
        save(snapshot)
    }

    func syncArrivals(stopID: Int, arrivals: [WatchArrivalSnapshot]) {
        var snapshot = loadSnapshot()
        snapshot.generatedAt = Date()
        snapshot.arrivalsByStopID["\(stopID)"] = arrivals
        save(snapshot)
    }

    func loadSnapshot() -> WatchTransitSnapshot {
        guard let data = userDefaults.data(forKey: Config.snapshotKey) else {
            return .empty
        }
        return (try? decoder.decode(WatchTransitSnapshot.self, from: data)) ?? .empty
    }

    private func save(_ snapshot: WatchTransitSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        userDefaults.set(data, forKey: Config.snapshotKey)
    }
}
