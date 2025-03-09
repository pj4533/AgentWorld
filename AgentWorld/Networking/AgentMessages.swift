//
//  AgentMessages.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

// MARK: - Agent Request Message Types

// Base protocol for all agent requests
protocol AgentRequest: Codable {
    var requestType: String { get }
}

// Move action request
struct MoveRequest: AgentRequest {
    let requestType = "action"
    let action: String
    let targetTile: TargetPosition
    
    struct TargetPosition: Codable {
        let x: Int
        let y: Int
    }
}

// Query request for information about the world
struct QueryRequest: AgentRequest {
    let requestType = "query"
    let query: String
    let parameters: [String: String]?
}

// System message for connection management
struct SystemRequest: AgentRequest {
    let requestType = "system"
    let system: String
    let parameters: [String: String]?
}

// MARK: - Agent Response Message Types

// Base protocol for all responses to agents
protocol AgentResponse: Codable {
    var responseType: String { get }
}

// We don't need these extensions anymore - the Observation types now have 
// responseType fields directly embedded

// Success response with optional data payload
struct SuccessResponse: AgentResponse {
    let responseType = "success"
    let message: String
    let data: [String: String]?
}

// MARK: - Agent Message Parsing

// Helper for parsing agent messages
struct AgentMessageParser {
    
    static func parseRequest(_ data: Data) throws -> (type: String, json: [String: Any])? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Determine message type
        if json["action"] != nil {
            return ("action", json)
        } else if json["query"] != nil {
            return ("query", json)
        } else if json["system"] != nil {
            return ("system", json)
        } else {
            // Try to extract from requestType field if present
            if let requestType = json["requestType"] as? String {
                return (requestType, json)
            }
        }
        
        return nil
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let agentsDidChange = Notification.Name("agentsDidChange")
    static let timeStepAdvanced = Notification.Name("timeStepAdvanced")
}