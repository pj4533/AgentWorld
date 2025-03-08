//
//  WorldTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/8/25.
//

import Testing
@testable import AgentWorld

@Suite struct WorldTests {
    
    @Test func testAgentPlacement() {
        var world = World()
        
        // Try to place an agent
        let position = world.placeAgent(id: "test-agent-1")
        
        // Verify agent was placed successfully
        #expect(position != nil)
        #expect(world.agents.count == 1)
        #expect(world.agents["test-agent-1"] != nil)
        
        // Verify agent is at expected position
        let agent = world.agents["test-agent-1"]
        #expect(agent?.position.x == position?.x)
        #expect(agent?.position.y == position?.y)
        
        // Verify the position is valid for an agent
        if let pos = position {
            #expect(world.isValidForAgent(x: pos.x, y: pos.y) == false, "Position should now be invalid since there's already an agent there")
        }
    }
    
    @Test func testAgentRemoval() {
        var world = World()
        
        // Place an agent
        let _ = world.placeAgent(id: "test-agent-1")
        #expect(world.agents.count == 1)
        
        // Remove the agent
        let removed = world.removeAgent(id: "test-agent-1")
        #expect(removed == true)
        #expect(world.agents.count == 0)
        
        // Try to remove a non-existent agent
        let nonExistentRemoved = world.removeAgent(id: "non-existent-agent")
        #expect(nonExistentRemoved == false)
    }
    
    @Test func testMoveAgent() {
        var world = World()
        
        // Place an agent
        let position = world.placeAgent(id: "test-agent-1")
        #expect(position != nil, "Failed to place agent")
        guard let validPosition = position else {
            return
        }
        
        // Try valid move (one step in any direction)
        let newX = min(validPosition.x + 1, World.size - 1)
        let newY = validPosition.y
        
        // Make sure the new position is valid
        if world.isValidForAgent(x: newX, y: newY) {
            let moved = world.moveAgent(id: "test-agent-1", to: (x: newX, y: newY))
            #expect(moved == true)
            #expect(world.agents["test-agent-1"]?.position.x == newX)
            #expect(world.agents["test-agent-1"]?.position.y == newY)
        }
        
        // Try invalid move (more than one step)
        let invalidMove = world.moveAgent(id: "test-agent-1", to: (x: validPosition.x + 2, y: validPosition.y + 2))
        #expect(invalidMove == false)
        
        // Try to move non-existent agent
        let nonExistentMove = world.moveAgent(id: "non-existent-agent", to: (x: 1, y: 1))
        #expect(nonExistentMove == false)
    }
    
    @Test func testIsValidForAgent() {
        var world = World()
        
        // Set up a test world with known tile types
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Set a mountain and water tile
        world.tiles[10][10] = .mountains
        world.tiles[15][15] = .water
        
        // Test valid position
        #expect(world.isValidForAgent(x: 5, y: 5) == true)
        
        // Test invalid positions
        #expect(world.isValidForAgent(x: 10, y: 10) == false, "Mountains should be invalid")
        #expect(world.isValidForAgent(x: 15, y: 15) == false, "Water should be invalid")
        #expect(world.isValidForAgent(x: -1, y: 5) == false, "Out of bounds should be invalid")
        #expect(world.isValidForAgent(x: World.size, y: 5) == false, "Out of bounds should be invalid")
        
        // Place an agent and verify its position becomes invalid
        let _ = world.placeAgent(id: "test-agent-1")
        if let agent = world.agents["test-agent-1"] {
            #expect(world.isValidForAgent(x: agent.position.x, y: agent.position.y) == false, 
                   "Position with an agent should be invalid")
        }
    }
    
    @Test func testSurroundings() {
        var world = World()
        
        // Set up a simple world with known tile types
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Place agents at known positions
        let agentID = "test-agent-1"
        world.agents[agentID] = AgentInfo(id: agentID, position: (x: 20, y: 20), color: .red)
        
        let otherAgentID = "test-agent-2"
        world.agents[otherAgentID] = AgentInfo(id: otherAgentID, position: (x: 22, y: 20), color: .blue)
        
        // Get surroundings
        let surroundings = world.surroundings(for: agentID)
        
        // Calculate expected number of tiles in surroundings
        let expectedTileCount = (2 * World.surroundingsRadius + 1) * (2 * World.surroundingsRadius + 1)
        #expect(surroundings.count == expectedTileCount)
        
        // Verify the agent can see itself
        let selfTile = surroundings.first { tile in
            tile.position.x == 20 && tile.position.y == 20
        }
        #expect(selfTile != nil)
        #expect(selfTile?.agentID == agentID)
        
        // Verify the agent can see the other agent
        let otherAgentTile = surroundings.first { tile in
            tile.position.x == 22 && tile.position.y == 20
        }
        #expect(otherAgentTile != nil)
        #expect(otherAgentTile?.agentID == otherAgentID)
    }
    
    @Test func testCreateObservation() {
        var world = World()
        
        // Set up a simple world with known tile types
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Add a specific tile type for testing
        world.tiles[22][20] = .trees
        
        // Place agents at known positions
        let agentID = "test-agent-1"
        world.agents[agentID] = AgentInfo(id: agentID, position: (x: 20, y: 20), color: .red)
        
        let otherAgentID = "test-agent-2"
        world.agents[otherAgentID] = AgentInfo(id: otherAgentID, position: (x: 22, y: 20), color: .blue)
        
        // Create observation
        let observation = world.createObservation(for: agentID, timeStep: 42)
        
        // Verify observation properties
        #expect(observation != nil)
        #expect(observation?.agent_id == agentID)
        #expect(observation?.timeStep == 42)
        #expect(observation?.currentLocation.x == 20)
        #expect(observation?.currentLocation.y == 20)
        #expect(observation?.currentLocation.type == "grass")
        
        // Verify surroundings contents
        let surroundingsCount = (2 * World.surroundingsRadius + 1) * (2 * World.surroundingsRadius + 1)
        #expect(observation?.surroundings.tiles.count == surroundingsCount)
        
        // Verify we can see the other agent
        let otherAgent = observation?.surroundings.agents.first
        #expect(otherAgent != nil)
        #expect(otherAgent?.agent_id == otherAgentID)
        #expect(otherAgent?.x == 22)
        #expect(otherAgent?.y == 20)
        
        // Verify non-existent agent returns nil
        let nonExistentObservation = world.createObservation(for: "non-existent-agent", timeStep: 42)
        #expect(nonExistentObservation == nil)
    }
}