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
    let dependencies = AppDependencies()
    @AppStorage(AppTheme.selectedPrimaryColorHexKey) private var selectedPrimaryColorHex = AppTheme.defaultPrimaryColorHex

    var body: some Scene {
        WindowGroup {
            MainTabView(dependencies: dependencies)
                .tint(AppTheme.color(forStoredHex: selectedPrimaryColorHex))
                .modelContainer(dependencies.modelContainer)
        }
    }
}
