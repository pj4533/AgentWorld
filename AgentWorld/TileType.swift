//
//  TileType.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation
import SwiftUI

enum TileType: Int, CaseIterable {
    case grass = 0
    case trees = 1
    case mountains = 2
    case water = 3
    case swamp = 4
    case desert = 5
    
    var color: NSColor {
        switch self {
        case .grass:
            return .green
        case .trees:
            return .darkGreen
        case .mountains:
            return .gray
        case .water:
            return .blue
        case .swamp:
            return NSColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 0.7)
        case .desert:
            return .yellow
        }
    }
    
    static let distribution: [TileType: Double] = [
        .grass: 0.3,
        .trees: 0.2,
        .mountains: 0.1,
        .water: 0.2,
        .swamp: 0.1,
        .desert: 0.1
    ]
}

extension NSColor {
    static var darkGreen: NSColor {
        return NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
    }
}