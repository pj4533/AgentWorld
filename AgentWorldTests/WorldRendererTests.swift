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
        
        // Check that we have the expected distribution of tile colors
        // Based on our checkerboard pattern, we should have equal numbers of water and grass tiles
        let waterColorNodes = scene.children.filter { node in
            guard let spriteNode = node as? SKSpriteNode else { return false }
            return spriteNode.color == TileType.water.color
        }
        
        let grassColorNodes = scene.children.filter { node in
            guard let spriteNode = node as? SKSpriteNode else { return false }
            return spriteNode.color == TileType.grass.color
        }
        
        let expectedCount = (World.size * World.size) / 2
        #expect(waterColorNodes.count == expectedCount)
        #expect(grassColorNodes.count == expectedCount)
    }
}

// Helper extension for float comparison in tests
private extension CGFloat {
    func isAlmostEqual(to other: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
        return abs(self - other) <= tolerance
    }
}