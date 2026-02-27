//
//  due_sp_watchBundle.swift
//  due-sp-watch
//
//  Created by Pedro Antunes on 26/02/2026.
//

import WidgetKit
import SwiftUI

@main
struct due_sp_watchBundle: WidgetBundle {
    var body: some Widget {
        due_sp_watch()
        due_sp_next_arrival()
        due_sp_nearby_stops()
    }
}
