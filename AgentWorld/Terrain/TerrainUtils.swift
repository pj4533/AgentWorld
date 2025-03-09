//
//  TerrainUtils.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

struct TerrainUtils {
    static func isCloseToTerrainType(x: Int, y: Int, type: TileType, radius: Int, world: World) -> Bool {
        for checkY in max(0, y - radius)..<min(World.size, y + radius) {
            for checkX in max(0, x - radius)..<min(World.size, x + radius) {
                if world.tiles[checkY][checkX] == type {
                    return true
                }
            }
        }
        return false
    }
    
    static func growTerrainType(_ type: TileType, toSize targetSize: Int, in world: inout World) {
        // Count current number of tiles
        var currentCount = 0
        for y in 0..<World.size {
            for x in 0..<World.size {
                if world.tiles[y][x] == type {
                    currentCount += 1
                }
            }
        }
        
        if currentCount >= targetSize {
            return // Already at or above target size
        }
        
        var iterations = 0
        while currentCount < targetSize && iterations < 100 {
            var frontier: [(Int, Int)] = []
            
            // Find edge of terrain type
            for y in 0..<World.size {
                for x in 0..<World.size {
                    if world.tiles[y][x] == type {
                        let neighbors = getNeighbors(x: x, y: y)
                        for neighbor in neighbors {
                            if world.tiles[neighbor.y][neighbor.x] == .grass {
                                frontier.append((neighbor.x, neighbor.y))
                            }
                        }
                    }
                }
            }
            
            // Shuffle frontier to grow in random directions
            frontier.shuffle()
            
            // Grow until we reach target size
            for (x, y) in frontier {
                if currentCount >= targetSize {
                    break
                }
                if world.tiles[y][x] == .grass {
                    world.tiles[y][x] = type
                    currentCount += 1
                }
            }
            
            iterations += 1
        }
    }
    
    static func getNeighbors(x: Int, y: Int) -> [(x: Int, y: Int)] {
        let directions = [
            (-1, 0), (1, 0), (0, -1), (0, 1)  // Left, Right, Up, Down
        ]
        
        var neighbors: [(x: Int, y: Int)] = []
        
        for (dx, dy) in directions {
            let newX = x + dx
            let newY = y + dy
            
            // Check bounds
            if newX >= 0 && newX < World.size && newY >= 0 && newY < World.size {
                neighbors.append((x: newX, y: newY))
            }
        }
        
        return neighbors
    }
}