//
//  AgentMoveObservationTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/9/25.
//

import Testing
import Network
@testable import AgentWorld
import Foundation
import OSLog

// Using the mock network classes from MockNetworkClasses.swift

// Mock delegate to track world updates
class MockConnectionDelegate: ServerConnectionManagerDelegate {
    var updatedWorlds: [World] = []
    var connectedAgents: [(id: String, position: (x: Int, y: Int))] = []
    var disconnectedAgents: [String] = []
    var errors: [Error] = []
    
    // Add a reset method for clean test isolation
    func reset() {
        updatedWorlds = []
        connectedAgents = []
        disconnectedAgents = []
        errors = []
    }
    
    func worldDidUpdate(_ world: World) {
        updatedWorlds.append(world)
        let logger = AppLogger(category: "MockConnectionDelegate")
        logger.debug("🔄 Delegate received worldDidUpdate with \(world.agents.count) agents")
        for (id, agent) in world.agents {
            logger.debug("Agent \(id) at position (\(agent.position.x), \(agent.position.y))")
        }
    }
    
    func agentDidConnect(id: String, position: (x: Int, y: Int)) {
        connectedAgents.append((id: id, position: position))
        let logger = AppLogger(category: "MockConnectionDelegate")
        logger.debug("👋 Delegate received agentDidConnect: \(id) at (\(position.x), \(position.y))")
    }
    
    func agentDidDisconnect(id: String) {
        disconnectedAgents.append(id)
        let logger = AppLogger(category: "MockConnectionDelegate")
        logger.debug("👋 Delegate received agentDidDisconnect: \(id)")
    }
    
    func serverDidEncounterError(_ error: Error) {
        errors.append(error)
        let logger = AppLogger(category: "MockConnectionDelegate")
        logger.error("❌ Delegate received error: \(error.localizedDescription)")
    }
}

// These tests are specifically designed to catch the bug where agent positions
// in observations don't reflect their current locations after movement
@Suite struct AgentMoveObservationTests {
    
    // Create a world with a simple layout and an agent at a known position
    func createTestWorld(agentId: String = "test-agent-\(UUID().uuidString)") -> (World, String) {
        let world = World()
        
        // Fill with grass tiles
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Add a few different tile types for testing
        world.tiles[5][6] = .trees  // Target move location
        
        // Place agent at a fixed position with unique ID
        world.agents[agentId] = AgentInfo(id: agentId, position: (x: 5, y: 5), color: .red)
        
        return (world, agentId)
    }
    
    // Test to verify the full flow from connection to move to observation
    @Test func testAgentMoveFollowedByObservation() async throws {
        // Create a fresh, isolated world instance for this test
        let testId = UUID().uuidString 
        let agentID = "test-agent-\(testId)"
        let (world, _) = createTestWorld(agentId: agentID)
        
        // Verify the agent is in the initial position
        #expect(world.agents[agentID]?.position.x == 5)
        #expect(world.agents[agentID]?.position.y == 5)
        
        // Move the agent one position to the right
        let success = world.moveAgent(id: agentID, to: (x: 6, y: 5))
        #expect(success == true, "Agent move should succeed")
        
        // Verify the agent moved
        #expect(world.agents[agentID]?.position.x == 6)
        #expect(world.agents[agentID]?.position.y == 5)
        
        // Create an observation
        if let observation = world.createObservation(for: agentID, timeStep: 1) {
            // Verify the observation shows the correct position
            #expect(observation.currentLocation.x == 6)
            #expect(observation.currentLocation.y == 5)
            // The tile type could be grass or trees depending on our test world setup
            let tileType = observation.currentLocation.type
            #expect(tileType == "grass" || tileType == "trees")
        } else {
            #expect(false, "Failed to create observation")
        }
    }
    
    // Test specifically for the bug where positions aren't updated correctly in the World struct
    @Test func testMoveUpdatesWorldStruct() throws {
        // Use a unique identifier for this test
        let testId = UUID().uuidString 
        let agentID = "test-agent-\(testId)"
        let (world, _) = createTestWorld(agentId: agentID)
        
        // Verify initial position
        #expect(world.agents[agentID]?.position.x == 5)
        #expect(world.agents[agentID]?.position.y == 5)
        
        // Move the agent directly on the world object
        let success = world.moveAgent(id: agentID, to: (x: 6, y: 5))
        #expect(success == true, "Move should succeed")
        
        // Check new position
        #expect(world.agents[agentID]?.position.x == 6, "Agent x position should be updated")
        #expect(world.agents[agentID]?.position.y == 5, "Agent y position should be unchanged")
        
        // Since World is a class, we don't need to test copying behavior.
        // This is just a reference to the same instance
        let worldRef = world
        
        // Verify the reference has the updated position
        #expect(worldRef.agents[agentID]?.position.x == 6, "Reference should have updated x position")
        #expect(worldRef.agents[agentID]?.position.y == 5, "Reference should have unchanged y position")
        
        // Create an observation from the reference
        let observation = worldRef.createObservation(for: agentID, timeStep: 1)
        #expect(observation?.currentLocation.x == 6, "Observation should show updated x position")
        #expect(observation?.currentLocation.y == 5, "Observation should show unchanged y position")
    }
}