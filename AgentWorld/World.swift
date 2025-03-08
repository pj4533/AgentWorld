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
        var world = World()
        
        // Step 1: Start with random seeds based on distribution
        for y in 0..<size {
            for x in 0..<size {
                let random = Double.random(in: 0...1)
                var cumulativeProbability = 0.0
                
                for (tileType, probability) in TileType.distribution {
                    cumulativeProbability += probability
                    if random <= cumulativeProbability {
                        world.tiles[y][x] = tileType
                        break
                    }
                }
            }
        }
        
        // Step 2: Organic expansion - each tile has a chance to convert neighbors to its type
        let iterations = 5
        
        for _ in 0..<iterations {
            var newTiles = world.tiles
            
            for y in 0..<size {
                for x in 0..<size {
                    // Get neighbors
                    let neighbors = getNeighbors(x: x, y: y, world: world)
                    
                    // 20% chance to spread to neighboring tiles
                    if Double.random(in: 0...1) < 0.2 {
                        // Choose a random neighbor
                        if let neighbor = neighbors.randomElement() {
                            newTiles[neighbor.y][neighbor.x] = world.tiles[y][x]
                        }
                    }
                }
            }
            
            world.tiles = newTiles
        }
        
        return world
    }
    
    private static func getNeighbors(x: Int, y: Int, world: World) -> [(x: Int, y: Int)] {
        let directions = [
            (-1, 0), (1, 0), (0, -1), (0, 1)  // Left, Right, Up, Down
        ]
        
        var neighbors: [(x: Int, y: Int)] = []
        
        for (dx, dy) in directions {
            let newX = x + dx
            let newY = y + dy
            
            // Check bounds
            if newX >= 0 && newX < size && newY >= 0 && newY < size {
                neighbors.append((x: newX, y: newY))
            }
        }
        
        return neighbors
    }
}