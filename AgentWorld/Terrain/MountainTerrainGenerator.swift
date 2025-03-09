//
//  MountainTerrainGenerator.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

struct MountainTerrainGenerator {
    static func generateMountainRanges(count: Int, targetSize: Int, in world: inout World) {
        // Calculate size per range
        let sizePerRange = targetSize / count
        var totalMountainTiles = 0
        
        for _ in 0..<count {
            // Start point for the mountain range
            let startX = Int.random(in: 5..<World.size-5)
            let startY = Int.random(in: 5..<World.size-5)
            
            // Direction and length of the range (adjust based on target size)
            let angle = Double.random(in: 0..<2 * Double.pi)
            let length = Int(sqrt(Double(sizePerRange))) + Int.random(in: 2...5)
            
            // Track mountain tiles for this range
            var mountainTiles: [(Int, Int)] = []
            
            // Create the mountain range along a line
            for i in 0..<length {
                let x = startX + Int(Double(i) * cos(angle))
                let y = startY + Int(Double(i) * sin(angle))
                
                // Check bounds
                if x >= 0 && x < World.size && y >= 0 && y < World.size {
                    mountainTiles.append((x, y))
                    
                    // Add some width to the mountain range
                    let width = max(1, Int(sqrt(Double(sizePerRange) / Double(length))))
                    for w in 1...width {
                        let wx = x + Int(Double(w) * cos(angle + Double.pi/2))
                        let wy = y + Int(Double(w) * sin(angle + Double.pi/2))
                        
                        if wx >= 0 && wx < World.size && wy >= 0 && wy < World.size {
                            mountainTiles.append((wx, wy))
                        }
                        
                        let wx2 = x + Int(Double(w) * cos(angle - Double.pi/2))
                        let wy2 = y + Int(Double(w) * sin(angle - Double.pi/2))
                        
                        if wx2 >= 0 && wx2 < World.size && wy2 >= 0 && wy2 < World.size {
                            mountainTiles.append((wx2, wy2))
                        }
                    }
                }
            }
            
            // Remove duplicates by using a dictionary as a set (since tuples aren't Hashable)
            var uniqueTiles: [String: (Int, Int)] = [:]
            for tile in mountainTiles {
                let key = "\(tile.0),\(tile.1)"
                uniqueTiles[key] = tile
            }
            mountainTiles = Array(uniqueTiles.values)
            
            // Limit to target size
            let rangeTargetSize = min(sizePerRange, targetSize - totalMountainTiles)
            if mountainTiles.count > rangeTargetSize {
                mountainTiles.shuffle()
                mountainTiles = Array(mountainTiles.prefix(rangeTargetSize))
            }
            
            // Place mountain tiles
            for (x, y) in mountainTiles {
                if world.tiles[y][x] == .grass { // Only replace grass
                    world.tiles[y][x] = .mountains
                    totalMountainTiles += 1
                }
            }
            
            // If we've reached the target size, stop adding ranges
            if totalMountainTiles >= targetSize {
                break
            }
        }
        
        // If we still need more mountains, grow existing ones
        if totalMountainTiles < targetSize {
            TerrainUtils.growTerrainType(.mountains, toSize: targetSize, in: &world)
        }
    }
}