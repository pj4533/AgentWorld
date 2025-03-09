//
//  ForestTerrainGenerator.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

struct ForestTerrainGenerator {
    static func generateForests(count: Int, targetSize: Int, in world: inout World) {
        // Calculate size per forest
        let sizePerForest = targetSize / count
        var totalForestTiles = 0
        
        for _ in 0..<count {
            // Create forest center
            let centerX = Int.random(in: 5..<World.size-5)
            let centerY = Int.random(in: 5..<World.size-5)
            
            // Calculate radius based on target size
            // Area of circle = π*r²
            let baseRadius = Int(sqrt(Double(sizePerForest) / Double.pi))
            
            // Track forest tiles
            var forestTiles: [(Int, Int)] = []
            
            // Create a forest with random edges
            for y in max(0, centerY - baseRadius*2)..<min(World.size, centerY + baseRadius*2) {
                for x in max(0, centerX - baseRadius*2)..<min(World.size, centerX + baseRadius*2) {
                    let distance = sqrt(pow(Double(x - centerX), 2) + pow(Double(y - centerY), 2))
                    let randomFactor = Double.random(in: 0.7...1.3)
                    
                    if distance < Double(baseRadius) * randomFactor {
                        forestTiles.append((x, y))
                    }
                }
            }
            
            // Limit to target size
            let forestTargetSize = min(sizePerForest, targetSize - totalForestTiles)
            if forestTiles.count > forestTargetSize {
                forestTiles.shuffle()
                forestTiles = Array(forestTiles.prefix(forestTargetSize))
            }
            
            // Place forest tiles
            for (x, y) in forestTiles {
                if world.tiles[y][x] == .grass { // Only replace grass
                    world.tiles[y][x] = .trees
                    totalForestTiles += 1
                    
                    if totalForestTiles >= targetSize {
                        break
                    }
                }
            }
            
            if totalForestTiles >= targetSize {
                break
            }
        }
        
        // If we still need more forest, grow existing ones
        if totalForestTiles < targetSize {
            TerrainUtils.growTerrainType(.trees, toSize: targetSize, in: &world)
        }
    }
}