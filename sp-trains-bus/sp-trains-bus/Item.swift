//
//  Item.swift
//  sp-trains-bus
//
//  Created by Pedro Antunes on 01/02/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
