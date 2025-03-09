//
//  SwampTerrainGenerator.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

struct SwampTerrainGenerator {
    static func generateSwamps(count: Int, targetSize: Int, in world: inout World) {
        // Calculate size per swamp
        let sizePerSwamp = targetSize / count
        var totalSwampTiles = 0
        
        for _ in 0..<count {
            // Swamps tend to be near water
            // Find a water tile to start near
            var waterTiles: [(x: Int, y: Int)] = []
            
            for y in 0..<World.size {
                for x in 0..<World.size {
                    if world.tiles[y][x] == .water {
                        waterTiles.append((x: x, y: y))
                    }
                }
            }
            
            // Calculate swamp center - either near water or random if no water
            var centerX = Int.random(in: 5..<World.size-5)
            var centerY = Int.random(in: 5..<World.size-5)
            
            if let waterTile = waterTiles.randomElement() {
                centerX = min(max(5, waterTile.x + Int.random(in: -5...5)), World.size-5)
                centerY = min(max(5, waterTile.y + Int.random(in: -5...5)), World.size-5)
            }
            
            // Calculate radius based on target size
            let baseRadius = Int(sqrt(Double(sizePerSwamp) / Double.pi))
            
            // Track swamp tiles
            var swampTiles: [(Int, Int)] = []
            
            // Create swamp with irregular shape
            for y in max(0, centerY - baseRadius*2)..<min(World.size, centerY + baseRadius*2) {
                for x in max(0, centerX - baseRadius*2)..<min(World.size, centerX + baseRadius*2) {
                    let distance = sqrt(pow(Double(x - centerX), 2) + pow(Double(y - centerY), 2))
                    let randomFactor = Double.random(in: 0.6...1.4) // More irregular for swamps
                    
                    if distance < Double(baseRadius) * randomFactor {
                        swampTiles.append((x, y))
                    }
                }
            }
            
            // Limit to target size
            let swampTargetSize = min(sizePerSwamp, targetSize - totalSwampTiles)
            if swampTiles.count > swampTargetSize {
                swampTiles.shuffle()
                swampTiles = Array(swampTiles.prefix(swampTargetSize))
            }
            
            // Place swamp tiles
            for (x, y) in swampTiles {
                if world.tiles[y][x] == .grass { // Only replace grass
                    world.tiles[y][x] = .swamp
                    totalSwampTiles += 1
                    
                    if totalSwampTiles >= targetSize {
                        break
                    }
                }
            }
            
            if totalSwampTiles >= targetSize {
                break
            }
        }
        
        // If we still need more swamp, grow existing ones
        if totalSwampTiles < targetSize {
            TerrainUtils.growTerrainType(.swamp, toSize: targetSize, in: &world)
        }
    }
}