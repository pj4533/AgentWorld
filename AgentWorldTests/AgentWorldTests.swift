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
        
        // Verify percentages are within reasonable bounds
        // We can't expect exact matches due to randomness in generation algorithm
        for tileType in TileType.allCases {
            let expectedPercentage = TileType.distribution[tileType] ?? 0.0
            let actualPercentage = actualDistribution[tileType] ?? 0.0
            
            // Allow a 5% tolerance due to random generation
            #expect(abs(expectedPercentage - actualPercentage) < 0.05,
                   "Expected \(tileType) to be \(expectedPercentage) but was \(actualPercentage)")
        }
    }
}

// Helper extension for double comparison in tests
private extension Double {
    func isAlmostEqual(to other: Double, tolerance: Double = 0.001) -> Bool {
        return abs(self - other) <= tolerance
    }
}
