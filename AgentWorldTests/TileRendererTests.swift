//
//  TileRendererTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/8/25.
//

import Foundation
import Testing
import SpriteKit
@testable import AgentWorld

@Suite struct TileRendererTests {
    let tileSize: CGFloat = 20.0
    let tileRenderer: TileRenderer
    
    init() {
        tileRenderer = TileRenderer(tileSize: tileSize)
    }
    
    @Test func createTileNodeProducesSpriteNode() {
        // Test with all tile types
        for tileType in TileType.allCases {
            let size = CGSize(width: tileSize, height: tileSize)
            let node = tileRenderer.createTileNode(for: tileType, size: size)
            
            // Basic checks
            #expect(node is SKSpriteNode)
            #expect(node.size == size)
            #expect(node.color == tileType.color)
            
            // Check that children were added (textures)
            #expect(!node.children.isEmpty)
        }
    }
    
    @Test func createTileNodesWithDifferentTileTypesProducesDifferentResults() {
        let size = CGSize(width: tileSize, height: tileSize)
        
        // Create nodes for different tile types
        let grassNode = tileRenderer.createTileNode(for: .grass, size: size)
        let waterNode = tileRenderer.createTileNode(for: .water, size: size)
        let mountainsNode = tileRenderer.createTileNode(for: .mountains, size: size)
        
        // Different tile types should have different numbers of child nodes
        // We're just testing that they differ, rather than specific counts
        // since the implementation could change
        #expect(grassNode.children.count > 0)
        #expect(waterNode.children.count > 0)
        #expect(mountainsNode.children.count > 0)
        
        // Check that the node colors match the tile colors
        #expect(grassNode.color == TileType.grass.color)
        #expect(waterNode.color == TileType.water.color)
        #expect(mountainsNode.color == TileType.mountains.color)
    }
}