//
//  AgentMessageHandlerTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/8/25.
//

import Testing
@testable import AgentWorld
import Foundation
import OSLog

// Mock logger for testing
class MockAppLogger {
    var debugMessages: [String] = []
    var infoMessages: [String] = []
    var errorMessages: [String] = []
    
    func debug(_ message: String) {
        debugMessages.append(message)
    }
    
    func info(_ message: String) {
        infoMessages.append(message)
    }
    
    func error(_ message: String) {
        errorMessages.append(message)
    }
}

// We'll use a protocol for our testing approach instead of trying to modify private properties
protocol LoggerProvider {
    var debugMessages: [String] { get }
    var infoMessages: [String] { get }
    var errorMessages: [String] { get }
    
    func debug(_ message: String)
    func info(_ message: String)
    func error(_ message: String)
}

// Make our mock logger conform to the protocol
extension MockAppLogger: LoggerProvider {}

@Suite struct AgentMessageHandlerTests {
    
    // Helper for standardized async completion handling
    func waitForAsyncCompletion(_ block: (@escaping () -> Void) -> Void) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        
        block {
            semaphore.signal()
        }
        
        // Use a longer timeout for reliability
        let result = semaphore.wait(timeout: .now() + 10.0)
        return result == .success
    }
    
    // Use the global helper function for standardized world creation
    // Create an independent handler for each test
    func createTestHandler() -> (AgentMessageHandler, String) {
        let (world, agentId) = createIsolatedTestWorld()
        return (AgentMessageHandler(world: world), agentId)
    }
    
    // Test initialization
    @Test func testInitialization() {
        let (handler, agentId) = createTestHandler()
        
        #expect(handler.world.agents.count == 1)
        #expect(handler.world.agents[agentId] != nil)
    }
    
    // Test updateWorld method
    @Test func testUpdateWorld() {
        let (handler, originalAgentId) = createTestHandler()
        
        // Create a new world with a different agent
        let newWorld = World()
        let newAgentId = "new-agent-\(UUID().uuidString)"
        newWorld.agents[newAgentId] = AgentInfo(id: newAgentId, position: (x: 10, y: 10), color: .blue)
        
        handler.updateWorld(newWorld)
        
        #expect(handler.world.agents.count == 1)
        #expect(handler.world.agents[newAgentId] != nil)
        #expect(handler.world.agents[originalAgentId] == nil)
    }
    
    // Test handling invalid message
    @Test func testHandleInvalidMessage() async {
        let (handler, agentId) = createTestHandler()
        
        // Create invalid JSON data
        let invalidData = "not valid json".data(using: .utf8)!
        
        var receivedResponse: Encodable?
        
        // Use the standardized helper for async handling
        let completed = waitForAsyncCompletion { completion in
            handler.handleMessage(invalidData, from: agentId) { response in
                receivedResponse = response
                completion()
            }
        }
        
        #expect(completed, "Timed out waiting for response after 10 seconds")
        
        // Now check the response after we're sure it's been received
        if let errorResponse = receivedResponse as? Observation.ErrorResponse {
            #expect(errorResponse.error == "Invalid message format")
        } else {
            #expect(false, "Expected error response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling unknown message type
    @Test func testHandleUnknownMessageType() async {
        let (handler, agentId) = createTestHandler()
        
        // Create unknown message type
        let unknownMessage = ["unknown": "type"]
        let data = try! JSONSerialization.data(withJSONObject: unknownMessage)
        
        var receivedResponse: Encodable?
        
        // Use the standardized helper for async handling
        let completed = waitForAsyncCompletion { completion in
            handler.handleMessage(data, from: agentId) { response in
                receivedResponse = response
                completion()
            }
        }
        
        #expect(completed, "Timed out waiting for response after 10 seconds")
        
        if let errorResponse = receivedResponse as? Observation.ErrorResponse {
            #expect(errorResponse.error.contains("Unable to parse message"))
        } else {
            #expect(false, "Expected error response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling action message - move
    @Test func testHandleMoveAction() async throws {
        let (handler, agentId) = createTestHandler()
        
        // Get the initial position of the agent (always 5,5 in our test world)
        let initialX = handler.world.agents[agentId]!.position.x
        let initialY = handler.world.agents[agentId]!.position.y
        
        // Create a move action (to adjacent tile)
        let moveAction: [String: Any] = [
            "action": "move",
            "targetTile": ["x": initialX + 1, "y": initialY]
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: moveAction)
        
        var receivedResponse: Encodable?
        
        // Use the standardized helper for async handling
        let completed = waitForAsyncCompletion { completion in
            handler.handleMessage(data, from: agentId) { response in
                receivedResponse = response
                completion()
            }
        }
        
        #expect(completed, "Timed out waiting for response after 10 seconds")
        
        // Verify the agent moved
        if let agent = handler.world.agents[agentId] {
            #expect(agent.position.x == initialX + 1)
            #expect(agent.position.y == initialY)
        } else {
            #expect(false, "Agent not found in world")
        }
        
        // Verify success response type
        if let successResponse = receivedResponse as? SuccessResponse {
            #expect(successResponse.message == "Move successful")
            #expect(successResponse.data?["x"] == "\(initialX + 1)")
            #expect(successResponse.data?["y"] == "\(initialY)")
            #expect(successResponse.data?["currentTileType"] == "grass")
        } else {
            #expect(false, "Expected success response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling invalid move action
    @Test func testHandleInvalidMoveAction() async {
        let (handler, agentId) = createTestHandler()
        
        // Get the initial position of the agent
        let initialX = handler.world.agents[agentId]!.position.x
        let initialY = handler.world.agents[agentId]!.position.y
        
        // Create an invalid move (too far away)
        let invalidMoveAction: [String: Any] = [
            "action": "move",
            "targetTile": ["x": initialX + 5, "y": initialY + 5] // Too far from current position
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: invalidMoveAction)
        
        var receivedResponse: Encodable?
        
        // Use the standardized helper for async handling
        let completed = waitForAsyncCompletion { completion in
            handler.handleMessage(data, from: agentId) { response in
                receivedResponse = response
                completion()
            }
        }
        
        #expect(completed, "Timed out waiting for response after 10 seconds")
        
        // Verify the agent did not move
        #expect(handler.world.agents[agentId]?.position.x == initialX)
        #expect(handler.world.agents[agentId]?.position.y == initialY)
        
        // Verify error response
        if let errorResponse = receivedResponse as? Observation.ErrorResponse {
            #expect(errorResponse.error.contains("Invalid move"))
        } else {
            #expect(false, "Expected error response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling query message - observation
    @Test func testHandleObservationQuery() async throws {
        let (handler, agentId) = createTestHandler()
        
        // Create a query for observation
        let queryMessage: [String: Any] = [
            "query": "observation",
            "parameters": ["timeStep": "0"]
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: queryMessage)
        
        var receivedResponse: Encodable?
        
        // Use the standardized helper for async handling
        let completed = waitForAsyncCompletion { completion in
            handler.handleMessage(data, from: agentId) { response in
                receivedResponse = response
                completion()
            }
        }
        
        #expect(completed, "Timed out waiting for response after 10 seconds")
        
        // Verify success response (not observation, as we changed the behavior)
        if let successResponse = receivedResponse as? SuccessResponse {
            #expect(successResponse.message == "Observations are only sent at timestep changes")
            #expect(successResponse.data?["agentId"] == agentId)
        } else {
            #expect(false, "Expected success response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling query message - status
    @Test func testHandleStatusQuery() async {
        let (handler, agentId) = createTestHandler()
        
        // Create a query for status
        let queryMessage: [String: Any] = [
            "query": "status"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: queryMessage)
        
        var receivedResponse: Encodable?
        
        // Use the standardized helper for async handling
        let completed = waitForAsyncCompletion { completion in
            handler.handleMessage(data, from: agentId) { response in
                receivedResponse = response
                completion()
            }
        }
        
        #expect(completed, "Timed out waiting for response after 10 seconds")
        
        // Verify success response
        if let successResponse = receivedResponse as? SuccessResponse {
            #expect(successResponse.message == "Server is operational")
            #expect(successResponse.data?["status"] == "online")
            #expect(successResponse.data?["agents"] == "1")
        } else {
            #expect(false, "Expected success response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling system message - ping
    @Test func testHandlePingSystemMessage() async {
        let (handler, agentId) = createTestHandler()
        
        // Create a ping system message
        let systemMessage: [String: Any] = [
            "system": "ping"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: systemMessage)
        
        var receivedResponse: Encodable?
        
        // Use the standardized helper for async handling
        let completed = waitForAsyncCompletion { completion in
            handler.handleMessage(data, from: agentId) { response in
                receivedResponse = response
                completion()
            }
        }
        
        #expect(completed, "Timed out waiting for response after 10 seconds")
        
        // Verify pong response
        if let successResponse = receivedResponse as? SuccessResponse {
            #expect(successResponse.message == "pong")
            #expect(successResponse.data?["timestamp"] != nil)
        } else {
            #expect(false, "Expected success response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling system message - info
    @Test func testHandleInfoSystemMessage() async {
        let (handler, agentId) = createTestHandler()
        
        // Create an info system message
        let systemMessage: [String: Any] = [
            "system": "info"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: systemMessage)
        
        var receivedResponse: Encodable?
        
        // Use the standardized helper for async handling
        let completed = waitForAsyncCompletion { completion in
            handler.handleMessage(data, from: agentId) { response in
                receivedResponse = response
                completion()
            }
        }
        
        #expect(completed, "Timed out waiting for response after 10 seconds")
        
        // Verify info response
        if let successResponse = receivedResponse as? SuccessResponse {
            #expect(successResponse.message == "Server information")
            #expect(successResponse.data?["worldSize"] == "\(World.size)")
            #expect(successResponse.data?["agentCount"] == "1")
        } else {
            #expect(false, "Expected success response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling unknown system message
    @Test func testHandleUnknownSystemMessage() async {
        let (handler, agentId) = createTestHandler()
        
        // Create an unknown system message
        let systemMessage: [String: Any] = [
            "system": "unknown_command"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: systemMessage)
        
        var receivedResponse: Encodable?
        
        // Use the standardized helper for async handling
        let completed = waitForAsyncCompletion { completion in
            handler.handleMessage(data, from: agentId) { response in
                receivedResponse = response
                completion()
            }
        }
        
        #expect(completed, "Timed out waiting for response after 10 seconds")
        
        // Verify error response
        if let errorResponse = receivedResponse as? Observation.ErrorResponse {
            #expect(errorResponse.error.contains("Unknown system command"))
        } else {
            #expect(false, "Expected error response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling interact action (which is not implemented yet)
    @Test func testHandleInteractAction() async {
        let (handler, agentId) = createTestHandler()
        
        // Create an interact action
        let interactAction: [String: Any] = [
            "action": "interact",
            "target": "resource"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: interactAction)
        
        var receivedResponse: Encodable?
        
        // Use the standardized helper for async handling
        let completed = waitForAsyncCompletion { completion in
            handler.handleMessage(data, from: agentId) { response in
                receivedResponse = response
                completion()
            }
        }
        
        #expect(completed, "Timed out waiting for response after 10 seconds")
        
        // Verify not-implemented error response
        if let errorResponse = receivedResponse as? Observation.ErrorResponse {
            #expect(errorResponse.error.contains("Interact action not yet implemented"))
        } else {
            #expect(false, "Expected error response but got something else: \(String(describing: receivedResponse))")
        }
    }
}