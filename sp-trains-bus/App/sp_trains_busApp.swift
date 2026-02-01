//
//  sp_trains_busApp.swift
//  sp-trains-bus
//
//  Created by Pedro Antunes on 01/02/2026.
//

import SwiftUI

@main
struct sp_trains_busApp: App {
    let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            MainTabView(dependencies: dependencies)
        }
    }
}