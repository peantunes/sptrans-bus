import Foundation
import Combine

final class AppNavigationCoordinator: ObservableObject {
    @Published var pendingTabRawValue: String?
    @Published var pendingStop: Stop?
    @Published var pendingLineID: String?
    /// Token of a shared journey link (https://sptrans.lolados.app/j/<token>) to show.
    @Published var pendingSharedJourney: SharedJourneyToken?
    /// Shows the journey being tracked (from the Live Activity).
    @Published var showsTrackedJourney = false
    /// Keyboard / menu command for the trip planner, consumed by SearchView.
    @Published var plannerCommand: PlannerCommand?

    func select(_ tab: MainTabView.TabOption) {
        pendingTabRawValue = tab.rawValue
    }

    func send(_ command: PlannerCommand) {
        select(.search)
        plannerCommand = command
    }

    func handle(url: URL) {
        if let token = JourneyShareLink.token(from: url) {
            pendingSharedJourney = SharedJourneyToken(id: token)
            return
        }
        guard let deepLink = AppDeepLinkParser.parse(url: url) else { return }

        switch deepLink {
        case .status(let lineID):
            pendingTabRawValue = MainTabView.TabOption.status.rawValue
            pendingLineID = lineID
        case .stopDetail(let stop):
            pendingTabRawValue = MainTabView.TabOption.map.rawValue
            pendingStop = stop
        case .journey:
            showsTrackedJourney = true
        }
    }

    func consumePendingTab() -> String? {
        defer { pendingTabRawValue = nil }
        return pendingTabRawValue
    }

    func clearPendingStop() {
        pendingStop = nil
    }

    func clearPendingLine() {
        pendingLineID = nil
    }
}

/// Identifiable wrapper for presenting a shared journey sheet.
struct SharedJourneyToken: Identifiable, Equatable {
    let id: String
}

enum PlannerCommand: Equatable {
    case newTrip
    case findDestination
    case savedRoutes
    case search
}
