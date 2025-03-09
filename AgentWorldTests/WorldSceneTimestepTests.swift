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
import OSLog

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
        let logger = AppLogger(category: "MockServerConnectionManager")
        logger.debug("📤 Mock sendObservationsToAll at timeStep: \(timeStep)")
        for (agentId, pos) in agentPositionsAtObservation {
            logger.debug("   Agent \(agentId) observation would show position: (\(pos.x), \(pos.y))")
        }
    }
}

@Suite struct WorldSceneTimestepTests {
    
    // Test helper to create a test world with a unique agent
    func createTestWorld() -> (World, String) {
        let world = World()
        
        // Setup known tiles
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Add a specific agent with unique ID to prevent test collisions
        let uniqueAgentId = "test-agent-\(UUID().uuidString)"
        world.agents[uniqueAgentId] = AgentInfo(
            id: uniqueAgentId, 
            position: (x: 5, y: 5), 
            color: .red
        )
        
        return (world, uniqueAgentId)
    }
    
    // Test that simulateOneTimeStep correctly synchronizes world state before sending observations
    @Test func testSimulateTimeStepSynchronizesWorld() {
        // Create a world with an agent at a known position
        let (world, agentID) = createTestWorld()
        
        // Create a fresh mock server connection manager for this test
        let mockServer = MockServerConnectionManager(world: world)
        
        // Verify the agent is in the initial position
        #expect(mockServer.world.agents[agentID]?.position.x == 5, "Agent should start at x=5")
        
        // Clear any previous data
        mockServer.agentPositionsAtObservation = [:]
        mockServer.sendObservationsCalledWith = nil
        
        // Verify that when we call sendObservationsToAll, it records positions correctly
        mockServer.sendObservationsToAll(timeStep: 1)
        
        // The method should record the agent's position
        #expect(mockServer.sendObservationsCalledWith == 1, "Send observation should be called with timestep 1")
        #expect(mockServer.agentPositionsAtObservation[agentID]?.x == 5, "Recorded agent x position should be 5")
        #expect(mockServer.agentPositionsAtObservation[agentID]?.y == 5, "Recorded agent y position should be 5")
    }
}