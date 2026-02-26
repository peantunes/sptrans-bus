import Foundation
import Combine

final class WatchTransitViewModel: ObservableObject {
    @Published private(set) var snapshot: WatchTransitSnapshot = .empty

    private let store: WatchSnapshotStore

    init(store: WatchSnapshotStore = WatchSnapshotStore()) {
        self.store = store
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
        snapshot = store.loadSnapshot()
    }

    func arrivals(for stop: WatchStopSnapshot) -> [WatchArrivalSnapshot] {
        snapshot.arrivalsByStopID["\(stop.stopId)"] ?? []
    }
}
