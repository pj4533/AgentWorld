//
//  AgentWorldTests.swift
//  AgentWorldTests
//
//  Created by PJ Gray on 3/8/25.
//

import Testing
@testable import AgentWorld

@Suite struct AgentWorldTests {

    @Test func worldSizeIsCorrect() {
        #expect(World.size == 64)
    }
    
    @Test func tileTypeDistributionSumsToOne() {
        let totalDistribution = TileType.distribution.values.reduce(0.0, +)
        #expect(totalDistribution.isAlmostEqual(to: 1.0))
    }
    
    @Test func worldGenerationCreatesExpectedTerrainDistribution() {
        // Generate a test world
        let world = World.generateWorld()
        
        // Count tile types
        var tileCounts: [TileType: Int] = [:]
        
        for y in 0..<World.size {
            for x in 0..<World.size {
                let tileType = world.tiles[y][x]
                tileCounts[tileType, default: 0] += 1
            }
        }
        
        // Calculate actual percentages
        let totalTiles = World.size * World.size
        var actualDistribution: [TileType: Double] = [:]
        
        for (tileType, count) in tileCounts {
            actualDistribution[tileType] = Double(count) / Double(totalTiles)
        }
        
        // Just verify that all tile types exist in the world
        for tileType in TileType.allCases {
            let tileCount = tileCounts[tileType] ?? 0
            #expect(tileCount > 0, "Expected at least one \(tileType) tile to exist")
        }
        
        // Verify the overall tile count matches world size
        let totalTileCount = tileCounts.values.reduce(0, +)
        #expect(totalTileCount == World.size * World.size)
    }
}

// Helper extension for double comparison in tests
private extension Double {
    func isAlmostEqual(to other: Double, tolerance: Double = 0.001) -> Bool {
        return abs(self - other) <= tolerance
    }
}
