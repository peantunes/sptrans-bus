#if os(watchOS)
import Foundation
import Combine

final class WatchTransitViewModel: ObservableObject {
    @Published private(set) var snapshot: WatchTransitSnapshot = .empty

    private let snapshotSync: WatchSnapshotSyncing

    init(snapshotSync: WatchSnapshotSyncing = WatchSnapshotStore()) {
        self.snapshotSync = snapshotSync
        reload()
    }

    var favoriteLinesFirst: [WatchRailLineSnapshot] {
        snapshot.railLines.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite && !rhs.isFavorite
            }
            if lhs.source != rhs.source {
                return lhs.source < rhs.source
            }
            let left = Int(lhs.lineNumber) ?? Int.max
            let right = Int(rhs.lineNumber) ?? Int.max
            return left < right
        }
    }

    func reload() {
        snapshot = snapshotSync.loadSnapshot()
    }

    func arrivals(for stop: WatchStopSnapshot) -> [WatchArrivalSnapshot] {
        snapshot.arrivalsByStopID["\(stop.stopId)"] ?? []
    }
}
#endif
