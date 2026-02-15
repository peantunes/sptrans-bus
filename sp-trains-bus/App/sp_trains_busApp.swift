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
    @AppStorage(AppTheme.selectedPrimaryColorHexKey) private var selectedPrimaryColorHex = AppTheme.defaultPrimaryColorHex
    @State private var hasTrackedAppOpen = false

    var body: some Scene {
        WindowGroup {
            MainTabView(dependencies: dependencies)
                .tint(AppTheme.color(forStoredHex: selectedPrimaryColorHex))
                .modelContainer(dependencies.modelContainer)
                .task {
                    startAnalyticsIfNeeded()
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
    }

    private func startAnalyticsIfNeeded() {
        dependencies.analyticsService.startSessionIfNeeded()

        guard !hasTrackedAppOpen else { return }
        hasTrackedAppOpen = true
        dependencies.analyticsService.trackEvent(name: "app_opened")
    }
}
