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
            
            let success = self.world.moveAgent(id: agentId, to: (x: targetX, y: targetY))
            
            if success {
                self.logger.info("Agent \(agentId) moved to (\(targetX), \(targetY))")
                
                // Notify the agent of success with a success response, NOT an observation
                // Observations should only be sent at timestep changes
                let successResponse = SuccessResponse(
                    message: "Move successful",
                    data: ["x": "\(targetX)", "y": "\(targetY)"]
                )
                completion(successResponse)
            } else {
                self.logger.info("Agent \(agentId) failed to move to (\(targetX), \(targetY))")
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