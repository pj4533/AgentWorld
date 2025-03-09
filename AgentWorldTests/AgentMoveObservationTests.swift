//
//  AgentMoveObservationTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/9/25.
//

import Testing
@testable import AgentWorld
import Foundation

// Mock delegate to track world updates
class MockConnectionDelegate: ServerConnectionManagerDelegate {
    var updatedWorlds: [World] = []
    var connectedAgents: [(id: String, position: (x: Int, y: Int))] = []
    var disconnectedAgents: [String] = []
    var errors: [Error] = []
    
    func worldDidUpdate(_ world: World) {
        updatedWorlds.append(world)
        print("🔄 Delegate received worldDidUpdate with \(world.agents.count) agents")
        for (id, agent) in world.agents {
            print("Agent \(id) at position (\(agent.position.x), \(agent.position.y))")
        }
    }
    
    func agentDidConnect(id: String, position: (x: Int, y: Int)) {
        connectedAgents.append((id: id, position: position))
        print("👋 Delegate received agentDidConnect: \(id) at (\(position.x), \(position.y))")
    }
    
    func agentDidDisconnect(id: String) {
        disconnectedAgents.append(id)
        print("👋 Delegate received agentDidDisconnect: \(id)")
    }
    
    func serverDidEncounterError(_ error: Error) {
        errors.append(error)
        print("❌ Delegate received error: \(error.localizedDescription)")
    }
}

// These tests are specifically designed to catch the bug where agent positions
// in observations don't reflect their current locations after movement
@Suite struct AgentMoveObservationTests {
    
    // Create a world with a simple layout and an agent at a known position
    func createTestWorld() -> World {
        var world = World()
        
        // Fill with grass tiles
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Add a few different tile types for testing
        world.tiles[5][6] = .trees  // Target move location
        
        // Place agent at a fixed position
        let agentID = "test-agent"
        world.agents[agentID] = AgentInfo(id: agentID, position: (x: 5, y: 5), color: .red)
        
        return world
    }
    
    // Test to verify the full flow from connection to move to observation
    @Test func testAgentMoveFollowedByObservation() throws {
        // Create our test world
        var world = createTestWorld()
        
        // Create a delegate to track world updates
        let delegate = MockConnectionDelegate()
        
        // Create a ServerConnectionManager with our world
        let manager = ServerConnectionManager(world: world)
        manager.delegate = delegate
        
        // Verify initial state
        #expect(manager.world.agents.count == 1)
        let agentID = "test-agent"
        #expect(manager.world.agents[agentID]?.position.x == 5)
        #expect(manager.world.agents[agentID]?.position.y == 5)
        
        // Simulate agent connection (should already be in the world)
        print("🧪 TEST: Initial agent position: (5, 5)")
        
        // Create message handler that uses the same world
        let messageHandler = AgentMessageHandler(world: manager.world)
        messageHandler.delegate = delegate
        
        // 1. Simulate a move action (agent wants to move right from (5,5) to (6,5))
        print("🧪 TEST: Simulating move action to (6, 5)")
        let moveAction: [String: Any] = [
            "action": "move",
            "targetTile": ["x": 6, "y": 5]
        ]
        let moveData = try JSONSerialization.data(withJSONObject: moveAction)
        
        // Wait for the completion handler with a semaphore
        let semaphore = DispatchSemaphore(value: 0)
        var moveResponse: Encodable?
        messageHandler.handleMessage(moveData, from: agentID) { response in
            moveResponse = response
            print("🧪 TEST: Received move response")
            semaphore.signal()
        }
        
        // Wait for the completion handler
        _ = semaphore.wait(timeout: .now() + 1.0)
        
        // 2. Verify the agent moved in the message handler's world
        print("🧪 TEST: Checking agent position in message handler")
        #expect(messageHandler.world.agents[agentID]?.position.x == 6)
        #expect(messageHandler.world.agents[agentID]?.position.y == 5)
        
        // 3. Verify the agent also moved in the server connection manager's world
        print("🧪 TEST: Checking agent position in server connection manager")
        #expect(manager.world.agents[agentID]?.position.x == 6)
        #expect(manager.world.agents[agentID]?.position.y == 5)
        
        // 4. Verify the move response is a success
        if let successResponse = moveResponse as? SuccessResponse {
            print("🧪 TEST: Move was successful")
            #expect(successResponse.message == "Move successful")
        } else {
            print("❌ TEST: Move response was not a success")
            #expect(false, "Expected success response but got \(String(describing: moveResponse))")
        }
        
        // 5. Create observation for the next timestep
        print("🧪 TEST: Creating next timestep observation")
        let observation = manager.world.createObservation(for: agentID, timeStep: 1)
        
        // 6. Verify observation contains updated position
        #expect(observation != nil)
        print("🧪 TEST: Observation current location: (\(observation?.currentLocation.x ?? -1), \(observation?.currentLocation.y ?? -1))")
        #expect(observation?.currentLocation.x == 6)
        #expect(observation?.currentLocation.y == 5)
        #expect(observation?.currentLocation.type == "trees") // Should be trees tile at (6,5)
        
        // 7. Simulate a time step which would create and send observations
        print("🧪 TEST: Simulating sendObservationsToAll")
        // Just getting and reusing the server's world is part of our bugfix
        let worldBeforeTimestep = manager.world
        
        // Verify this world has the right agent position
        print("🧪 TEST: World before timestep agent at: (\(worldBeforeTimestep.agents[agentID]?.position.x ?? -1), \(worldBeforeTimestep.agents[agentID]?.position.y ?? -1))")
        #expect(worldBeforeTimestep.agents[agentID]?.position.x == 6)
        #expect(worldBeforeTimestep.agents[agentID]?.position.y == 5)
    }
    
    // Test specifically for the bug where positions aren't updated correctly in the World struct
    @Test func testMoveUpdatesWorldStruct() throws {
        // Create a world with an agent
        var world = World()
        
        // Fill with grass tiles
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Add an agent at (5,5)
        let agentID = "test-agent"
        world.agents[agentID] = AgentInfo(id: agentID, position: (x: 5, y: 5), color: .red)
        
        // Verify initial position
        #expect(world.agents[agentID]?.position.x == 5)
        #expect(world.agents[agentID]?.position.y == 5)
        
        // Move the agent directly on the world struct
        let success = world.moveAgent(id: agentID, to: (x: 6, y: 5))
        #expect(success == true, "Move should succeed")
        
        // Check new position
        #expect(world.agents[agentID]?.position.x == 6, "Agent x position should be updated")
        #expect(world.agents[agentID]?.position.y == 5, "Agent y position should be unchanged")
        
        // Make a copy of the world (simulating what happens in the actual code)
        let worldCopy = world
        
        // Verify the copy has the updated position
        #expect(worldCopy.agents[agentID]?.position.x == 6, "Copy should have updated x position")
        #expect(worldCopy.agents[agentID]?.position.y == 5, "Copy should have unchanged y position")
        
        // Create an observation from the copy
        let observation = worldCopy.createObservation(for: agentID, timeStep: 1)
        #expect(observation?.currentLocation.x == 6, "Observation should show updated x position")
        #expect(observation?.currentLocation.y == 5, "Observation should show unchanged y position")
    }
}