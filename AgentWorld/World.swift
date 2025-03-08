//
//  World.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation
import AppKit

struct AgentInfo {
    let id: String
    var position: (x: Int, y: Int)
    let color: NSColor
    
    init(id: String, position: (x: Int, y: Int), color: NSColor) {
        self.id = id
        self.position = position
        self.color = color
    }
}

struct TileInfo {
    let position: (x: Int, y: Int)
    let type: TileType
    let agentID: String?
    
    init(position: (x: Int, y: Int), type: TileType, agentID: String? = nil) {
        self.position = position
        self.type = type
        self.agentID = agentID
    }
}

struct Observation: Codable {
    let agent_id: String
    let currentLocation: TilePosition
    let surroundings: Surroundings
    let timeStep: Int
    private let responseType: String = "observation" // For protocol conformance
    
    struct TilePosition: Codable {
        let x: Int
        let y: Int
        let type: String
    }
    
    struct Surroundings: Codable {
        let tiles: [TileObservation]
        let agents: [AgentObservation]
    }
    
    struct TileObservation: Codable {
        let x: Int
        let y: Int
        let type: String
    }
    
    struct AgentObservation: Codable {
        let agent_id: String
        let x: Int
        let y: Int
    }
    
    struct ErrorResponse: Codable {
        let error: String
        private let responseType: String = "error" // For protocol conformance
    }
}

struct World {
    static let size = 64
    static let surroundingsRadius = 5 // How far agents can see around them
    
    var tiles: [[TileType]]
    var agents: [String: AgentInfo] = [:]
    
    init() {
        // Initialize with empty tiles
        tiles = Array(repeating: Array(repeating: .grass, count: World.size), count: World.size)
    }
    
    static func generateWorld() -> World {
        return WorldGenerator.generateWorld()
    }
    
    mutating func placeAgent(id: String) -> (x: Int, y: Int)? {
        // Find a valid position (not water or mountains)
        for _ in 0..<100 { // Try up to 100 times to find a valid spot
            let x = Int.random(in: 0..<World.size)
            let y = Int.random(in: 0..<World.size)
            
            // Check if the tile is valid for agent placement (not water, mountains, or occupied)
            if isValidForAgent(x: x, y: y) {
                // Generate a random color for the agent
                let randomColor = NSColor(
                    red: CGFloat.random(in: 0.2...1.0),
                    green: CGFloat.random(in: 0.2...1.0),
                    blue: CGFloat.random(in: 0.2...1.0),
                    alpha: 1.0
                )
                
                // Create and store agent info
                let agentInfo = AgentInfo(id: id, position: (x: x, y: y), color: randomColor)
                agents[id] = agentInfo
                
                return (x: x, y: y)
            }
        }
        
        return nil // Failed to find a valid position
    }
    
    func isValidForAgent(x: Int, y: Int) -> Bool {
        // Check if position is in bounds
        guard x >= 0 && x < World.size && y >= 0 && y < World.size else {
            return false
        }
        
        // Check if tile is not water or mountains
        let tileType = tiles[y][x]
        if tileType == .water || tileType == .mountains {
            return false
        }
        
        // Check if there's already an agent at this position
        for agent in agents.values {
            if agent.position.x == x && agent.position.y == y {
                return false
            }
        }
        
        return true
    }
    
    mutating func moveAgent(id: String, to position: (x: Int, y: Int)) -> Bool {
        // Verify the agent exists
        guard var agent = agents[id] else {
            return false
        }
        
        // Check if the position is valid
        if !isValidForAgent(x: position.x, y: position.y) {
            return false
        }
        
        // Check if the move is valid (only one tile distance)
        let currentPos = agent.position
        let dx = abs(position.x - currentPos.x)
        let dy = abs(position.y - currentPos.y)
        
        // Ensure the agent only moves one tile in any direction (including diagonal)
        if dx > 1 || dy > 1 {
            return false
        }
        
        // Update agent position
        agent.position = position
        agents[id] = agent
        
        return true
    }
    
    func surroundings(for agentID: String) -> [TileInfo] {
        guard let agent = agents[agentID] else {
            return []
        }
        
        var result: [TileInfo] = []
        let pos = agent.position
        
        // Get all tiles within the surroundings radius
        for dy in -World.surroundingsRadius...World.surroundingsRadius {
            for dx in -World.surroundingsRadius...World.surroundingsRadius {
                let x = pos.x + dx
                let y = pos.y + dy
                
                // Check if position is in bounds
                if x >= 0 && x < World.size && y >= 0 && y < World.size {
                    // Find if there's an agent at this position
                    var agentIDAtTile: String? = nil
                    for (id, agentInfo) in agents {
                        if agentInfo.position.x == x && agentInfo.position.y == y {
                            agentIDAtTile = id
                            break
                        }
                    }
                    
                    result.append(TileInfo(
                        position: (x: x, y: y),
                        type: tiles[y][x],
                        agentID: agentIDAtTile
                    ))
                }
            }
        }
        
        return result
    }
    
    func createObservation(for agentID: String, timeStep: Int) -> Observation? {
        guard let agent = agents[agentID] else {
            return nil
        }
        
        let surroundingTiles = surroundings(for: agentID)
        
        // Convert to observation format
        let tileObservations = surroundingTiles.map { tileInfo in
            Observation.TileObservation(
                x: tileInfo.position.x,
                y: tileInfo.position.y,
                type: tileInfo.type.description
            )
        }
        
        // Get agent observations (other agents in the surroundings area)
        let agentObservations = surroundingTiles.compactMap { tileInfo -> Observation.AgentObservation? in
            guard let otherAgentID = tileInfo.agentID, otherAgentID != agentID else {
                return nil
            }
            
            return Observation.AgentObservation(
                agent_id: otherAgentID,
                x: tileInfo.position.x,
                y: tileInfo.position.y
            )
        }
        
        // Current agent position and tile type
        let pos = agent.position
        let currentTileType = tiles[pos.y][pos.x]
        
        return Observation(
            agent_id: agentID,
            currentLocation: Observation.TilePosition(
                x: pos.x,
                y: pos.y,
                type: currentTileType.description
            ),
            surroundings: Observation.Surroundings(
                tiles: tileObservations,
                agents: agentObservations
            ),
            timeStep: timeStep
        )
    }
}