//
//  World.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

struct World {
    static let size = 64
    var tiles: [[TileType]]
    
    init() {
        // Initialize with empty tiles
        tiles = Array(repeating: Array(repeating: .grass, count: World.size), count: World.size)
    }
    
    static func generateWorld() -> World {
        return WorldGenerator.generateWorld()
    }
}