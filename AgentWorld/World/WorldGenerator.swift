//
//  WorldGenerator.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

struct WorldGenerator {
    static func generateWorld() -> World {
        var world = World()
        
        // First fill the world with grass (base terrain)
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Calculate target counts for each terrain type based on distribution
        let totalTiles = World.size * World.size
        var targetCounts: [TileType: Int] = [:]
        for (type, percentage) in TileType.distribution {
            targetCounts[type] = Int(Double(totalTiles) * percentage)
        }
        
        // Reserve grass tiles (no need to explicitly generate them)
        var remainingTiles = totalTiles
        remainingTiles -= targetCounts[.grass] ?? 0
        
        // Allocate tiles for each terrain feature
        // Water: One large ocean (60-70% of water) + small lakes
        let waterTarget = targetCounts[.water] ?? 0
        let oceanSize = Int(Double(waterTarget) * Double.random(in: 0.6...0.7))
        let lakesSize = waterTarget - oceanSize
        
        // Generate features with appropriate sizes
        TerrainGenerator.generateOcean(size: oceanSize, in: &world)
        TerrainGenerator.generateLakes(size: lakesSize, in: &world)
        TerrainGenerator.generateMountainRanges(count: Int.random(in: 1...2), targetSize: targetCounts[.mountains] ?? 0, in: &world)
        TerrainGenerator.generateForests(count: Int.random(in: 1...3), targetSize: targetCounts[.trees] ?? 0, in: &world)
        TerrainGenerator.generateDeserts(count: Int.random(in: 1...2), targetSize: targetCounts[.desert] ?? 0, in: &world)
        TerrainGenerator.generateSwamps(count: Int.random(in: 1...2), targetSize: targetCounts[.swamp] ?? 0, in: &world)
        
        return world
    }
}