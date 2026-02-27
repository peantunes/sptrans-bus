import Foundation
import Combine

@MainActor
final class WatchTransitViewModel: ObservableObject {
    @Published private(set) var snapshot: WatchTransitSnapshot = .empty
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    private let apiService: SharedTransitAPIService
    private let store: WatchSnapshotStore

    init(
        apiService: SharedTransitAPIService? = nil,
        store: WatchSnapshotStore? = nil
    ) {
        self.apiService = apiService ?? SharedTransitAPIService()
        self.store = store ?? WatchSnapshotStore()
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
        Task {
            await loadSnapshot()
        }
    }

    func arrivals(for stop: WatchStopSnapshot) -> [WatchArrivalSnapshot] {
        snapshot.arrivalsByStopID["\(stop.stopId)"] ?? []
    }

    private func loadSnapshot() async {
        isLoading = true
        errorMessage = nil

        let preferredStopID = store.loadPreferredStopID()
        let sharedSnapshot = await apiService.fetchSnapshot(preferredStopID: preferredStopID)
        let mappedSnapshot = WatchTransitSnapshot(sharedSnapshot: sharedSnapshot)

        snapshot = mappedSnapshot
        if mappedSnapshot.railLines.isEmpty && mappedSnapshot.nearbyStops.isEmpty {
            errorMessage = "Unable to load live data"
        }
        isLoading = false
    }
}
