//
//  Item.swift
//  CyclingBuddy
//
//  Created by Olivia Mac on 2/20/26.
//

import Foundation
import SwiftData

@available(iOS 17, *)
@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
