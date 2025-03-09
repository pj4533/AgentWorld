//
//  DesertTerrainGenerator.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

struct DesertTerrainGenerator {
    static func generateDeserts(count: Int, targetSize: Int, in world: inout World) {
        // Calculate size per desert
        let sizePerDesert = targetSize / count
        var totalDesertTiles = 0
        
        for _ in 0..<count {
            // Create desert center
            let centerX = Int.random(in: 5..<World.size-5)
            let centerY = Int.random(in: 5..<World.size-5)
            
            // Calculate radius based on target size
            let baseRadius = Int(sqrt(Double(sizePerDesert) / Double.pi))
            
            // Track desert tiles
            var desertTiles: [(Int, Int)] = []
            
            // Create a desert with softer edges
            for y in max(0, centerY - baseRadius*2)..<min(World.size, centerY + baseRadius*2) {
                for x in max(0, centerX - baseRadius*2)..<min(World.size, centerX + baseRadius*2) {
                    let distance = sqrt(pow(Double(x - centerX), 2) + pow(Double(y - centerY), 2))
                    let randomFactor = Double.random(in: 0.8...1.2)
                    
                    if distance < Double(baseRadius) * randomFactor {
                        desertTiles.append((x, y))
                    }
                }
            }
            
            // Limit to target size
            let desertTargetSize = min(sizePerDesert, targetSize - totalDesertTiles)
            if desertTiles.count > desertTargetSize {
                desertTiles.shuffle()
                desertTiles = Array(desertTiles.prefix(desertTargetSize))
            }
            
            // Place desert tiles
            for (x, y) in desertTiles {
                if world.tiles[y][x] == .grass { // Only replace grass
                    world.tiles[y][x] = .desert
                    totalDesertTiles += 1
                    
                    if totalDesertTiles >= targetSize {
                        break
                    }
                }
            }
            
            if totalDesertTiles >= targetSize {
                break
            }
        }
        
        // If we still need more desert, grow existing ones
        if totalDesertTiles < targetSize {
            TerrainUtils.growTerrainType(.desert, toSize: targetSize, in: &world)
        }
    }
}