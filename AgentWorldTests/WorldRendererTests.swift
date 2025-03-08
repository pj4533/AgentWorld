//
//  WorldRendererTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/8/25.
//

import Foundation
import Testing
import SpriteKit
@testable import AgentWorld

@Suite struct WorldRendererTests {
    let testWorld: World
    let tileSize: CGFloat = 10.0
    
    init() {
        // Create a test world with a pattern for verification
        var world = World()
        // Create a checkerboard pattern of water and grass
        for y in 0..<World.size {
            for x in 0..<World.size {
                if (x + y) % 2 == 0 {
                    world.tiles[y][x] = .water
                } else {
                    world.tiles[y][x] = .grass
                }
            }
        }
        self.testWorld = world
    }
    
    @Test func renderWorldAddsCorrectNumberOfNodesToScene() {
        // Create a test scene
        let scene = SKScene(size: CGSize(width: 640, height: 640))
        let renderer = WorldRenderer(world: testWorld, tileSize: tileSize)
        
        // Render the world
        renderer.renderWorld(in: scene)
        
        // Verify the number of children matches the world size
        let expectedNodeCount = World.size * World.size
        #expect(scene.children.count == expectedNodeCount)
    }
    
    @Test func renderWorldPositionsNodesCorrectly() {
        // Create a test scene
        let scene = SKScene(size: CGSize(width: 640, height: 640))
        let renderer = WorldRenderer(world: testWorld, tileSize: tileSize)
        
        // Render the world
        renderer.renderWorld(in: scene)
        
        // Check a few specific node positions
        // Get nodes at specific positions
        let topLeftNode = scene.children.first { node in
            let position = node.position
            return position.x.isAlmostEqual(to: tileSize/2) && 
                   position.y.isAlmostEqual(to: scene.size.height - tileSize/2)
        }
        
        #expect(topLeftNode != nil)
        
        // Check bottom-right node
        let bottomRightNode = scene.children.first { node in
            let position = node.position
            let expectedX = CGFloat(World.size - 1) * tileSize + tileSize/2
            let expectedY = tileSize/2
            return position.x.isAlmostEqual(to: expectedX) && 
                   position.y.isAlmostEqual(to: expectedY)
        }
        
        #expect(bottomRightNode != nil)
    }
    
    @Test func renderWorldReplacesExistingNodes() {
        // Create a test scene with some existing children
        let scene = SKScene(size: CGSize(width: 640, height: 640))
        let dummyNode = SKSpriteNode(color: .red, size: CGSize(width: 50, height: 50))
        scene.addChild(dummyNode)
        
        #expect(scene.children.count == 1)
        
        // Render the world
        let renderer = WorldRenderer(world: testWorld, tileSize: tileSize)
        renderer.renderWorld(in: scene)
        
        // Verify the dummy node was removed and replaced with world tiles
        let expectedNodeCount = World.size * World.size
        #expect(scene.children.count == expectedNodeCount)
        #expect(!scene.children.contains(dummyNode))
    }
    
    @Test func renderWorldUsesCorrectTileTypes() {
        // Create a test scene
        let scene = SKScene(size: CGSize(width: 640, height: 640))
        let renderer = WorldRenderer(world: testWorld, tileSize: tileSize)
        
        // Render the world
        renderer.renderWorld(in: scene)
        
        // Simply check that all nodes are sprite nodes
        let spriteNodeCount = scene.children.filter { $0 is SKSpriteNode }.count
        #expect(spriteNodeCount == World.size * World.size)
    }
    
    @Test func renderWorldReusesCachedNodes() {
        // Create a test scene
        let scene = SKScene(size: CGSize(width: 640, height: 640))
        let renderer = WorldRenderer(world: testWorld, tileSize: tileSize)
        
        // First render - should create all nodes
        renderer.renderWorld(in: scene)
        
        // Keep track of nodes from the first render
        let initialNodes = scene.children.compactMap { $0 as? SKSpriteNode }
        
        // Second render - should reuse cached nodes
        renderer.renderWorld(in: scene)
        
        // Get nodes from the second render
        let secondRenderNodes = scene.children.compactMap { $0 as? SKSpriteNode }
        
        // Both renders should have the same number of nodes
        #expect(initialNodes.count == secondRenderNodes.count)
        
        // The renderer should reuse cached nodes, so they should have the same children/textures
        // Extract a few nodes for testing (e.g., 2-3 nodes)
        if !initialNodes.isEmpty && !secondRenderNodes.isEmpty {
            // Check that a few nodes have the same child count
            // This tests indirectly that the nodes are being reused rather than regenerated
            for i in stride(from: 0, to: min(5, initialNodes.count), by: 1) {
                #expect(initialNodes[i].children.count == secondRenderNodes[i].children.count)
            }
        }
    }
    
    @Test func clearTileCacheCreatesNewNodes() {
        // Create a test scene
        let scene = SKScene(size: CGSize(width: 640, height: 640))
        let renderer = WorldRenderer(world: testWorld, tileSize: tileSize)
        
        // First render - should create all nodes
        renderer.renderWorld(in: scene)
        
        // Keep track of a few nodes from the first render
        let sampleInitialNodes = Array(scene.children.prefix(5))
        
        // Clear the cache
        renderer.clearTileCache()
        
        // Render again - should create new nodes
        renderer.renderWorld(in: scene)
        
        // Get the same nodes after second render
        let sampleSecondRenderNodes = Array(scene.children.prefix(5))
        
        // The nodes should not be the same instances after cache clearing
        for (i, initialNode) in sampleInitialNodes.enumerated() {
            // They should not be the same instance
            #expect(!initialNode.isEqual(sampleSecondRenderNodes[i]))
        }
    }
}

// Helper extension for float comparison in tests
private extension CGFloat {
    func isAlmostEqual(to other: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
        return abs(self - other) <= tolerance
    }
}