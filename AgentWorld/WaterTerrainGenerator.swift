//
//  WaterTerrainGenerator.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

struct WaterTerrainGenerator {
    static func generateOcean(size targetSize: Int, in world: inout World) {
        // Place ocean with irregular shape
        let oceanCenterX = Int.random(in: 5..<World.size-5)
        let oceanCenterY = Int.random(in: 5..<World.size-5)
        
        // Calculate base radius based on target size
        // Area of circle = π*r²
        let baseRadius = Int(sqrt(Double(targetSize) / Double.pi)) + 3 // Add some padding
        
        // Create initial ocean shape
        var oceanTiles: [(Int, Int)] = []
        for y in 0..<World.size {
            for x in 0..<World.size {
                let distance = sqrt(pow(Double(x - oceanCenterX), 2) + pow(Double(y - oceanCenterY), 2))
                // Use noise to create irregular coastline
                let noiseValue = Double.random(in: 0.7...1.3)
                if distance < Double(baseRadius) * noiseValue {
                    oceanTiles.append((x, y))
                }
            }
        }
        
        // Trim or expand to match target size
        if oceanTiles.count > targetSize {
            // Remove furthest tiles
            oceanTiles.sort { a, b in
                let distA = sqrt(pow(Double(a.0 - oceanCenterX), 2) + pow(Double(a.1 - oceanCenterY), 2))
                let distB = sqrt(pow(Double(b.0 - oceanCenterX), 2) + pow(Double(b.1 - oceanCenterY), 2))
                return distA < distB
            }
            oceanTiles = Array(oceanTiles.prefix(targetSize))
        }
        
        // Place ocean tiles
        for (x, y) in oceanTiles {
            world.tiles[y][x] = .water
        }
        
        // If needed, grow ocean to match target size
        var currentSize = oceanTiles.count
        var iterations = 0
        
        while currentSize < targetSize && iterations < 100 {
            var frontier: [(Int, Int)] = []
            
            // Find edge of water
            for y in 0..<World.size {
                for x in 0..<World.size {
                    if world.tiles[y][x] == .water {
                        let neighbors = TerrainUtils.getNeighbors(x: x, y: y)
                        for neighbor in neighbors {
                            if world.tiles[neighbor.y][neighbor.x] != .water {
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
                if currentSize >= targetSize {
                    break
                }
                if world.tiles[y][x] != .water {
                    world.tiles[y][x] = .water
                    currentSize += 1
                }
            }
            
            iterations += 1
        }
    }
    
    static func generateLakes(size targetSize: Int, in world: inout World) {
        // Create 2-4 smaller lakes
        let lakeCount = min(Int.random(in: 2...4), targetSize / 10 + 1) // Make sure we don't create too many small lakes
        let sizePerLake = targetSize / lakeCount
        
        for i in 0..<lakeCount {
            // Find location away from existing water
            var lakeCenterX = Int.random(in: 5..<World.size-5)
            var lakeCenterY = Int.random(in: 5..<World.size-5)
            var attempts = 0
            
            // Try to place lake away from ocean
            while attempts < 10 {
                let tooCloseToWater = TerrainUtils.isCloseToTerrainType(x: lakeCenterX, y: lakeCenterY, type: .water, radius: 10, world: world)
                if !tooCloseToWater {
                    break
                }
                lakeCenterX = Int.random(in: 5..<World.size-5)
                lakeCenterY = Int.random(in: 5..<World.size-5)
                attempts += 1
            }
            
            // Calculate lake radius based on target size
            let lakeSize = min(sizePerLake, targetSize - (i * sizePerLake))
            let baseRadius = Int(sqrt(Double(lakeSize) / Double.pi))
            
            // Create lake with irregular shape
            var lakeTiles: [(Int, Int)] = []
            for y in max(0, lakeCenterY - baseRadius*2)..<min(World.size, lakeCenterY + baseRadius*2) {
                for x in max(0, lakeCenterX - baseRadius*2)..<min(World.size, lakeCenterX + baseRadius*2) {
                    let distance = sqrt(pow(Double(x - lakeCenterX), 2) + pow(Double(y - lakeCenterY), 2))
                    let noiseValue = Double.random(in: 0.6...1.4) // More variation for lakes
                    if distance < Double(baseRadius) * noiseValue {
                        lakeTiles.append((x, y))
                    }
                }
            }
            
            // Trim if needed
            if lakeTiles.count > lakeSize {
                lakeTiles.sort { a, b in
                    let distA = sqrt(pow(Double(a.0 - lakeCenterX), 2) + pow(Double(a.1 - lakeCenterY), 2))
                    let distB = sqrt(pow(Double(b.0 - lakeCenterX), 2) + pow(Double(b.1 - lakeCenterY), 2))
                    return distA < distB
                }
                lakeTiles = Array(lakeTiles.prefix(lakeSize))
            }
            
            // Place lake tiles
            for (x, y) in lakeTiles {
                world.tiles[y][x] = .water
            }
        }
    }
}