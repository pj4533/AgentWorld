//
//  MessageService.swift
//  AgentWorld
//
//  Created by Claude on 3/9/25.
//

import Foundation
import OSLog

class MessageService {
    private let logger = AppLogger(category: "MessageService")
    
    func getMessageType<T: Encodable>(for message: T) -> String {
        if message is Observation {
            return "observation"
        } else if message is SuccessResponse {
            return "success" 
        } else if message is Observation.ErrorResponse {
            return "error"
        } else {
            return String(describing: type(of: message))
        }
    }
    
    func send<T: Encodable>(_ message: T, to agentId: String, via handler: ConnectionHandler, completion: (() -> Void)? = nil) {
        let messageType = getMessageType(for: message)
        
        handler.send(message) { error in
            if error == nil {
                self.logger.info("Sent message type: \(messageType) to \(agentId)")
            }
            completion?()
        }
    }
    
    func logObservationDetails(_ observation: Observation, agentId: String) {
        logger.info("📤 Sending observation to agent \(agentId)")
        logger.info("   - Position: \(observation.currentLocation.x), \(observation.currentLocation.y)")
        logger.info("   - Tile type: \(observation.currentLocation.type)")
        logger.info("   - Timestep: \(observation.timeStep)")
    }
    
    func verifyObservationPosition(_ observation: Observation, agent: AgentInfo) -> Bool {
        let positionsMatch = observation.currentLocation.x == agent.position.x && 
                             observation.currentLocation.y == agent.position.y
                             
        if !positionsMatch {
            logger.error("⚠️ CRITICAL ERROR: Observation position \(observation.currentLocation.x), \(observation.currentLocation.y)" +
                       " doesn't match world state \(agent.position.x), \(agent.position.y)")
        }
        
        return positionsMatch
    }
}