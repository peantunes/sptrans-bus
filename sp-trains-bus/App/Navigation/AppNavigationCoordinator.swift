import Foundation
import Combine

final class AppNavigationCoordinator: ObservableObject {
    @Published var pendingTabRawValue: String?
    @Published var pendingStop: Stop?
    @Published var pendingLineID: String?

    func handle(url: URL) {
        guard let deepLink = AppDeepLinkParser.parse(url: url) else { return }

        switch deepLink {
        case .status(let lineID):
            pendingTabRawValue = MainTabView.TabOption.status.rawValue
            pendingLineID = lineID
        case .stopDetail(let stop):
            pendingTabRawValue = MainTabView.TabOption.map.rawValue
            pendingStop = stop
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
