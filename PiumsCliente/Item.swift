//
//  Item.swift
//  PiumsCliente
//
//  Created by piums on 9/04/26.
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
