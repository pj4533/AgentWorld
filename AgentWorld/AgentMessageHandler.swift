//
//  AgentMessageHandler.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation
import OSLog

// MARK: - Agent Message Handler
class AgentMessageHandler {
    private let logger = AppLogger(category: "AgentMessageHandler")
    private(set) var world: World
    
    // Delegate to notify about world changes
    weak var delegate: ServerConnectionManagerDelegate?
    
    init(world: World) {
        self.world = world
    }
    
    // Updates the world reference
    func updateWorld(_ newWorld: World) {
        self.world = newWorld
    }
    
    // Handle received messages from agents
    func handleMessage(_ data: Data, from agentId: String, completion: @escaping (Encodable?) -> Void) {
        if let string = String(data: data, encoding: .utf8) {
            logger.debug("Received from \(agentId): \(string)")
        }
        
        do {
            // Use the message parser to determine the type
            guard let parsedMessage = try AgentMessageParser.parseRequest(data) else {
                sendError(to: agentId, message: "Unable to parse message", completion: completion)
                return
            }
            
            logger.info("Processed message of type \(parsedMessage.type) from \(agentId)")
            
            // Route by message type
            switch parsedMessage.type {
            case "action":
                handleActionMessage(parsedMessage.json, agentId: agentId, completion: completion)
            case "query":
                handleQueryMessage(parsedMessage.json, agentId: agentId, completion: completion)
            case "system":
                handleSystemMessage(parsedMessage.json, agentId: agentId, completion: completion)
            default:
                sendError(to: agentId, message: "Unknown message type: \(parsedMessage.type)", completion: completion)
            }
        } catch {
            logger.error("Error parsing message from \(agentId): \(error.localizedDescription)")
            sendError(to: agentId, message: "Invalid message format", completion: completion)
        }
    }
    
    // Handle action-type messages
    private func handleActionMessage(_ json: [String: Any], 
                                    agentId: String, 
                                    completion: @escaping (Encodable?) -> Void) {
        // Extract the action type
        guard let action = json["action"] as? String else {
            sendError(to: agentId, message: "Missing action field", completion: completion)
            return
        }
        
        // Process based on action type
        switch action.lowercased() {
        case "move":
            // Try to parse a structured move request
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: json)
                let moveRequest = try JSONDecoder().decode(MoveRequest.self, from: jsonData)
                
                // Process the move action
                handleMoveAction(
                    agentId: agentId,
                    targetX: moveRequest.targetTile.x,
                    targetY: moveRequest.targetTile.y,
                    completion: completion
                )
            } catch {
                // Fall back to manual parsing for backward compatibility
                if let targetTile = json["targetTile"] as? [String: Int],
                   let x = targetTile["x"],
                   let y = targetTile["y"] {
                    handleMoveAction(agentId: agentId, targetX: x, targetY: y, completion: completion)
                } else {
                    sendError(to: agentId, message: "Invalid move request format", completion: completion)
                }
            }
            
        case "interact":
            // Handle interaction action (future feature)
            sendError(to: agentId, message: "Interact action not yet implemented", completion: completion)
            
        default:
            sendError(to: agentId, message: "Unknown action: \(action)", completion: completion)
        }
    }
    
    // Handle query-type messages
    private func handleQueryMessage(_ json: [String: Any], 
                                   agentId: String, 
                                   completion: @escaping (Encodable?) -> Void) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json)
            let queryRequest = try JSONDecoder().decode(QueryRequest.self, from: jsonData)
            
            // Process the query based on its type
            switch queryRequest.query.lowercased() {
            case "observation":
                // Instead of sending an observation, inform the agent to wait for the next timestep
                let response = SuccessResponse(
                    message: "Observations are only sent at timestep changes",
                    data: ["agentId": agentId]
                )
                completion(response)
                
            case "status":
                // Return server status information
                let response = SuccessResponse(
                    message: "Server is operational",
                    data: ["status": "online", "agents": "\(world.agents.count)"]
                )
                completion(response)
                
            default:
                sendError(to: agentId, message: "Unknown query type: \(queryRequest.query)", completion: completion)
            }
        } catch {
            sendError(to: agentId, message: "Invalid query format", completion: completion)
        }
    }
    
    // Handle system-type messages
    private func handleSystemMessage(_ json: [String: Any], 
                                    agentId: String, 
                                    completion: @escaping (Encodable?) -> Void) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json)
            let systemRequest = try JSONDecoder().decode(SystemRequest.self, from: jsonData)
            
            // Process the system message based on type
            switch systemRequest.system.lowercased() {
            case "ping":
                // Simple ping-pong for connection testing
                let response = SuccessResponse(
                    message: "pong",
                    data: ["timestamp": "\(Date().timeIntervalSince1970)"]
                )
                completion(response)
                
            case "info":
                // Return information about the server
                let response = SuccessResponse(
                    message: "Server information",
                    data: [
                        "worldSize": "\(World.size)",
                        "agentCount": "\(world.agents.count)"
                    ]
                )
                completion(response)
                
            default:
                sendError(to: agentId, message: "Unknown system command: \(systemRequest.system)", completion: completion)
            }
        } catch {
            sendError(to: agentId, message: "Invalid system message format", completion: completion)
        }
    }
    
    // Handle move action
    private func handleMoveAction(agentId: String, targetX: Int, targetY: Int, completion: @escaping (Encodable?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Log the agent's current position before movement
            if let agentInfo = self.world.agents[agentId] {
                self.logger.info("Agent \(agentId) current position before move: (\(agentInfo.position.x), \(agentInfo.position.y))")
            } else {
                self.logger.error("⚠️ Agent \(agentId) not found in world before move")
                self.sendError(to: agentId, message: "Agent not found in world", completion: completion)
                return
            }
            
            // Get the current position for logging before any change
            let startingPos = self.world.agents[agentId]?.position ?? (-1, -1)
            
            // CRITICAL CHANGE: Directly modify the world instance (no copying)
            var success = self.world.moveAgent(id: agentId, to: (x: targetX, y: targetY))
            
            // After direct modification, verify the position is updated
            if success {
                // Verify the agent's position was actually updated
                guard let agent = self.world.agents[agentId],
                      agent.position.x == targetX && agent.position.y == targetY else {
                    self.logger.error("⚠️ Agent position not updated correctly after move operation")
                    self.logger.error("⚠️ Move was from \(startingPos) to target (\(targetX), \(targetY))")
                    self.sendError(to: agentId, message: "Internal error updating agent position", completion: completion)
                    return
                }
                
                // Log the successful direct update
                self.logger.info("⚡ DIRECT UPDATE: Agent \(agentId) moved from \(startingPos) to (\(targetX), \(targetY))")
                
                self.logger.info("✅ Agent \(agentId) moved to (\(targetX), \(targetY))")
                
                // Verify world state consistency
                if let verifiedAgent = self.world.agents[agentId] {
                    if verifiedAgent.position.x != targetX || verifiedAgent.position.y != targetY {
                        self.logger.error("⚠️ INCONSISTENCY: Agent \(agentId) position in world (\(verifiedAgent.position.x), \(verifiedAgent.position.y)) doesn't match target (\(targetX), \(targetY))")
                    } else {
                        self.logger.info("✓ Verified agent position is consistent: (\(verifiedAgent.position.x), \(verifiedAgent.position.y))")
                    }
                }
                
                // Notify the delegate that an agent has moved (USE DIFFERENT METHOD)
                // CRITICAL FIX: Use agentDidMove instead of worldDidUpdate to avoid circular updates
                if let delegate = self.delegate as? WorldSceneDelegate {
                    delegate.agentDidMove(id: agentId, to: (x: targetX, y: targetY))
                } else {
                    // Only if not our custom delegate, use the standard method
                    self.delegate?.worldDidUpdate(self.world)
                }
                
                // Publish a notification that agents have changed, but don't include world reference
                // to avoid potential circular references
                NotificationCenter.default.post(name: .agentsDidChange, object: nil)
                
                // Get current tile type at new position for debugging
                let tileType = self.world.tiles[targetY][targetX]
                self.logger.info("Agent \(agentId) is now on \(tileType.description) tile")
                
                // Create additional verification observation
                if let verificationObs = self.world.createObservation(for: agentId, timeStep: 0) {
                    self.logger.info("✓ Verification observation shows agent at (\(verificationObs.currentLocation.x), \(verificationObs.currentLocation.y)) on \(verificationObs.currentLocation.type) tile")
                }
                
                // Notify the agent of success with a success response and include current tile type
                let successResponse = SuccessResponse(
                    message: "Move successful",
                    data: [
                        "x": "\(targetX)", 
                        "y": "\(targetY)",
                        "currentTileType": tileType.description
                    ]
                )
                completion(successResponse)
            } else {
                self.logger.info("❌ Agent \(agentId) failed to move to (\(targetX), \(targetY))")
                self.sendError(to: agentId, message: "Invalid move - tile is not passable or is occupied", completion: completion)
            }
        }
    }
    
    // Create and send error response
    private func sendError(to agentId: String, message: String, completion: @escaping (Encodable?) -> Void) {
        let errorResponse = Observation.ErrorResponse(error: message)
        completion(errorResponse)
    }
}