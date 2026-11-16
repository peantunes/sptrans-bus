//
//  sp_trains_busApp.swift
//  sp-trains-bus
//
//  Created by Pedro Antunes on 01/02/2026.
//

import SwiftUI
import SwiftData

@main
struct sp_trains_busApp: App {
    @Environment(\.scenePhase) private var scenePhase
    let dependencies = AppDependencies()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var navigationCoordinator = AppNavigationCoordinator()
    @AppStorage(AppTheme.selectedPrimaryColorHexKey) private var selectedPrimaryColorHex = AppTheme.defaultPrimaryColorHex
    @State private var hasTrackedAppOpen = false

    var body: some Scene {
        WindowGroup {
            MainTabView(dependencies: dependencies, navigationCoordinator: navigationCoordinator)
                .tint(AppTheme.color(forStoredHex: selectedPrimaryColorHex))
                .modelContainer(dependencies.modelContainer)
                .task {
                    startAnalyticsIfNeeded()
                    await PremiumSubscriptionStore.shared.refreshEntitlements()
                }
                .onOpenURL { url in
                    navigationCoordinator.handle(url: url)
                }
                // Universal links (shared journeys, https://sptrans.lolados.app/j/<token>).
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { navigationCoordinator.handle(url: url) }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        startAnalyticsIfNeeded()
                    case .background:
                        dependencies.analyticsService.endSession()
                    default:
                        break
                    }
                }
        }
        .commands {
            AppCommands(coordinator: navigationCoordinator)
        }
    }

    private func startAnalyticsIfNeeded() {
        dependencies.analyticsService.startSessionIfNeeded()

        guard !hasTrackedAppOpen else { return }
        hasTrackedAppOpen = true
        dependencies.analyticsService.trackEvent(name: "app_opened")
    }
}

/// Keyboard shortcuts and menu bar commands (iPad with a keyboard, iPhone Duo with a keyboard).
private struct AppCommands: Commands {
    let coordinator: AppNavigationCoordinator

    var body: some Commands {
        CommandMenu(Text("Navigate")) {
            Button("Map") { coordinator.select(.map) }.keyboardShortcut("1")
            if FeatureToggles.isSearchEnabled {
                Button("Plan a trip") { coordinator.select(.search) }.keyboardShortcut("2")
            }
            Button("Status") { coordinator.select(.status) }.keyboardShortcut("3")
            Button("Settings") { coordinator.select(.settings) }.keyboardShortcut("4")
        }
        if FeatureToggles.isSearchEnabled {
            CommandMenu(Text("Trip")) {
                Button("New trip") { coordinator.send(.newTrip) }.keyboardShortcut("n")
                Button("Choose destination") { coordinator.send(.findDestination) }.keyboardShortcut("f")
                Button("Search journeys") { coordinator.send(.search) }.keyboardShortcut(.return, modifiers: .command)
                Button("Saved routes") { coordinator.send(.savedRoutes) }.keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}
