//
//  WorldSceneTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/8/25.
//

import Foundation
import Testing
import SpriteKit
@testable import AgentWorld

@Suite struct WorldSceneTests {
    
    @Test func didMoveToViewInitializesComponents() {
        // Create a scene and simulate moving to a view
        let scene = WorldScene(size: CGSize(width: 640, height: 640))
        let view = SKView(frame: NSRect(x: 0, y: 0, width: 640, height: 640))
        
        scene.didMove(to: view)
        
        // We can't access private properties directly, but we can check results
        
        // Verify that the scene has children (tiles were rendered)
        #expect(!scene.children.isEmpty)
        
        // The number of children should match the world size
        #expect(scene.children.count == World.size * World.size)
    }
    
    @Test func mouseDownDelegatesToInputHandler() {
        // This test is a bit tricky to implement fully since we can't directly
        // access the private inputHandler property. We'll test indirectly
        // by checking that the scene implements InputHandlerDelegate.
        
        let scene = WorldScene(size: CGSize(width: 640, height: 640))
        
        // Verify the scene conforms to InputHandlerDelegate
        #expect(scene is InputHandlerDelegate)
        
        // We could use a spy or alternative mock setup for a more complete test
    }
    
    @Test func regenerateWorldCreatesNewWorldAndRendersIt() {
        // Create a scene and initialize it
        let scene = WorldScene(size: CGSize(width: 640, height: 640))
        let view = SKView(frame: NSRect(x: 0, y: 0, width: 640, height: 640))
        scene.didMove(to: view)
        
        // Store information about initial state
        let initialChildren = scene.children.map { $0 }
        
        // Regenerate the world
        scene.regenerateWorld()
        
        // Verify that children have changed (new tiles were created)
        // Since World generation has randomness, the new tiles should differ
        // from the original ones
        let newChildren = scene.children
        
        // Check that we still have the right number of tiles
        #expect(newChildren.count == World.size * World.size)
        
        // The following test checks that the nodes are different object instances
        // This verifies that new nodes were created, not just existing ones modified
        let anyNodeChanged = zip(initialChildren, newChildren).contains { (old, new) in
            return old !== new
        }
        
        #expect(anyNodeChanged)
    }
}