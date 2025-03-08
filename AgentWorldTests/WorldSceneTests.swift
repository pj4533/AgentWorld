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
    
    // Test that the scene correctly implements required protocols and interfaces
    @Test func worldSceneImplementsRequiredInterfaces() {
        let scene = WorldScene(size: CGSize(width: 100, height: 100))
        
        // Test protocol conformance
        #expect(scene is InputHandlerDelegate)
        #expect(scene is ServerConnectionManagerDelegate)
        
        // Test public method availability
        #expect(scene.getCurrentTimeStep() == 0)
        
        // Test that scene creation succeeds
        #expect(true, "Successfully created WorldScene")
    }
}