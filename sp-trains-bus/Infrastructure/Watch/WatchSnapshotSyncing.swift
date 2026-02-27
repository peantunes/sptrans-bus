import Foundation

protocol WatchSnapshotSyncing {
    func syncRailStatus(lines: [WatchRailLineSnapshot])
    func syncNearbyStops(stops: [WatchStopSnapshot])
    func syncArrivals(stopID: Int, arrivals: [WatchArrivalSnapshot])
    func syncPreferredStop(stopID: Int?)
    func loadSnapshot() -> WatchTransitSnapshot
}

struct NoOpWatchSnapshotSync: WatchSnapshotSyncing {
    func syncRailStatus(lines: [WatchRailLineSnapshot]) {}
    func syncNearbyStops(stops: [WatchStopSnapshot]) {}
    func syncArrivals(stopID: Int, arrivals: [WatchArrivalSnapshot]) {}
    func syncPreferredStop(stopID: Int?) {}
    func loadSnapshot() -> WatchTransitSnapshot { .empty }
}
