//
//  Item.swift
//  InputPilot
//
//  Created by Luca on 09.02.26.
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
