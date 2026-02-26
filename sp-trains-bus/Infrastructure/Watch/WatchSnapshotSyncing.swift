import Foundation

protocol WatchSnapshotSyncing {
    func syncRailStatus(lines: [WatchRailLineSnapshot])
    func syncNearbyStops(stops: [WatchStopSnapshot])
    func syncArrivals(stopID: Int, arrivals: [WatchArrivalSnapshot])
    func loadSnapshot() -> WatchTransitSnapshot
}

struct NoOpWatchSnapshotSync: WatchSnapshotSyncing {
    func syncRailStatus(lines: [WatchRailLineSnapshot]) {}
    func syncNearbyStops(stops: [WatchStopSnapshot]) {}
    func syncArrivals(stopID: Int, arrivals: [WatchArrivalSnapshot]) {}
    func loadSnapshot() -> WatchTransitSnapshot { .empty }
}
