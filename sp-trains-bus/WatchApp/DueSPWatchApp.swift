#if os(watchOS)
import SwiftUI

@main
struct DueSPWatchApp: App {
    @StateObject private var viewModel = WatchTransitViewModel()

    var body: some Scene {
        WindowGroup {
            WatchHomeView(viewModel: viewModel)
        }
    }
}
#endif
