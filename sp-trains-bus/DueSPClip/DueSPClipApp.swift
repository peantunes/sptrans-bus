//
//  DueSPClipApp.swift
//  DueSPClip
//
//  App Clip for shared journeys. iOS opens it from https://sptrans.lolados.app/j/<token> on a device
//  without Due SP; it shows that one journey, stop by stop, with Metro/CPTM line status from the server.
//

import SwiftUI

@main
struct DueSPClipApp: App {
    @StateObject private var model = ClipModel()

    var body: some Scene {
        WindowGroup {
            ClipRootView(model: model)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { model.open(url) }
                }
                .onOpenURL { model.open($0) }
                .task { model.applyLaunchArguments() }
        }
    }
}

@MainActor
final class ClipModel: ObservableObject {
    enum State {
        /// Launched without a link (for example from the App Library).
        case empty
        case loading
        case loaded(ClipSharedJourney)
        case failed(notFound: Bool)
    }

    @Published private(set) var state: State = .empty
    private(set) var token: String?
    private let client = ClipShareClient()

    func open(_ url: URL) {
        guard let token = ClipShareClient.token(from: url) else { return }
        open(token: token)
    }

    func open(token: String) {
        self.token = token
        state = .loading
        Task { await refresh() }
    }

    func refresh() async {
        guard let token else { return }
        do {
            let shared = try await client.load(token: token)
            guard token == self.token else { return }
            state = .loaded(shared)
        } catch let error as ClipShareClient.Failure {
            // Keep what is on screen when only a refresh failed.
            if case .loaded = state, error != .notFound { return }
            state = .failed(notFound: error == .notFound)
        } catch {}
    }

    /// Re-checks line status every minute while the clip is on screen.
    func keepRefreshing() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            if case .loaded = state { await refresh() }
        }
    }

    /// Xcode passes the invocation URL in `_XCAppClipURL`; `--duesp-clip-token=<token>` does the same in DEBUG.
    func applyLaunchArguments() {
        guard token == nil else { return }
        if let value = ProcessInfo.processInfo.environment["_XCAppClipURL"], let url = URL(string: value) {
            open(url)
        }
        #if DEBUG
        let prefix = "--duesp-clip-token="
        if token == nil, let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) {
            open(token: String(argument.dropFirst(prefix.count)))
        }
        #endif
    }
}
