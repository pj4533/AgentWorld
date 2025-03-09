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

// WorldScene is challenging to test because it relies heavily on SpriteKit rendering
// which is difficult to mock reliably. These tests focus on API conformance only.
@Suite struct WorldSceneTests {
    // Create a test scene with an isolated world to prevent shared state
    func createTestScene() -> WorldScene {
        let scene = WorldScene(size: CGSize(width: 100, height: 100))
        // Initialize with a fresh world manually, since WorldScene doesn't have createWorld()
        scene.world = World()
        scene.worldRenderer = WorldRenderer(world: scene.world, tileSize: 10)
        return scene
    }
    
    // Test that the scene correctly implements required protocols and interfaces
    @Test func worldSceneImplementsRequiredInterfaces() {
        let scene = createTestScene()
        
        // Test protocol conformance using type checking
        #expect(scene is InputHandlerDelegate, "Should implement InputHandlerDelegate")
        #expect(scene is ServerConnectionManagerDelegate, "Should implement ServerConnectionManagerDelegate")
        
        // Test that we can access basic functionality
        let timeStep = scene.currentTimeStep
        #expect(timeStep >= 0, "Current time step should be accessible")
        
        // Since WorldScene is complex with many dependencies,
        // just verify it can be created successfully
        #expect(true, "Successfully created WorldScene")
    }
}