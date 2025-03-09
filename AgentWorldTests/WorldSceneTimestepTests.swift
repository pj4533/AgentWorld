//
//  WorldSceneTimestepTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/9/25.
//

import Testing
@testable import AgentWorld
import Foundation
import SpriteKit

// Mock ServerConnectionManager for testing
class MockServerConnectionManager: ServerConnectionManager {
    // Track if sendObservationsToAll was called and with what parameters
    var sendObservationsCalledWith: Int? = nil
    
    // Track the agent positions at the time observations were sent
    var agentPositionsAtObservation: [String: (x: Int, y: Int)] = [:]
    
    override func sendObservationsToAll(timeStep: Int) {
        // Record that this method was called and with what time step
        sendObservationsCalledWith = timeStep
        
        // Record all agent positions at this point
        for (agentId, agentInfo) in world.agents {
            agentPositionsAtObservation[agentId] = agentInfo.position
        }
        
        // Instead of actually sending any network messages,
        // just log what would have been sent
        print("📤 Mock sendObservationsToAll at timeStep: \(timeStep)")
        for (agentId, pos) in agentPositionsAtObservation {
            print("   Agent \(agentId) observation would show position: (\(pos.x), \(pos.y))")
        }
    }
}

@Suite struct WorldSceneTimestepTests {
    
    // Test helper to create a test world
    func createTestWorld() -> World {
        var world = World()
        
        // Setup known tiles
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Add a specific agent
        world.agents["test-agent"] = AgentInfo(id: "test-agent", position: (x: 5, y: 5), color: .red)
        
        return world
    }
    
    // Test that simulateOneTimeStep correctly synchronizes world state before sending observations
    @Test func testSimulateTimeStepSynchronizesWorld() async throws {
        let world = createTestWorld()
        
        // Mock objects
        let mockServer = MockServerConnectionManager(world: world)
        let scene = WorldScene() // Create a real scene
        
        // Direct access to server connection manager now that it's internal
        scene.serverConnectionManager = mockServer
        
        // Set the world in the scene
        scene.setWorld(world)
        
        // Initialize the worldRenderer for testing (since didMove: isn't called in tests)
        scene.worldRenderer = WorldRenderer(world: world, tileSize: scene.tileSize)
        
        // Manually update the agent position in the server's world to simulate a move
        // This is what would happen after a successful move command
        var updatedWorld = mockServer.world
        let success = updatedWorld.moveAgent(id: "test-agent", to: (x: 6, y: 5))
        #expect(success)
        
        // Update the server's world with the moved agent
        mockServer.updateWorld(updatedWorld)
        
        // Verify the agent was moved in the server's world
        #expect(mockServer.world.agents["test-agent"]?.position.x == 6)
        #expect(mockServer.world.agents["test-agent"]?.position.y == 5)
        
        // But the scene's world still has the old position
        #expect(scene.world.agents["test-agent"]?.position.x == 5)
        #expect(scene.world.agents["test-agent"]?.position.y == 5)
        
        // Now simulate a time step - this would normally happen when the time steps forward
        // in the app, but we're calling it directly in the test
        scene.updateToTimeStep(1)
        
        // Verify the mock server's sendObservationsToAll was called
        #expect(mockServer.sendObservationsCalledWith == 1)
        
        // The critical test: verify agent positions were correct when observations were sent
        #expect(mockServer.agentPositionsAtObservation["test-agent"]?.x == 6)
        #expect(mockServer.agentPositionsAtObservation["test-agent"]?.y == 5)
    }
}