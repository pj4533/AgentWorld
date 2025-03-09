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
    
    // Test helper to create a world with predictable properties
    func createTestWorld() -> World {
        var world = World()
        
        // Setup known tiles
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Add a specific agent
        world.agents["test-agent"] = AgentInfo(id: "test-agent", position: (x: 5, y: 5), color: .red)
        
        return world
    }
    
    // Test initialization
    @Test func testInitialization() {
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        #expect(handler.world.agents.count == 1)
        #expect(handler.world.agents["test-agent"] != nil)
    }
    
    // Test updateWorld method
    @Test func testUpdateWorld() {
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        var newWorld = World()
        newWorld.agents["new-agent"] = AgentInfo(id: "new-agent", position: (x: 10, y: 10), color: .blue)
        
        handler.updateWorld(newWorld)
        
        #expect(handler.world.agents.count == 1)
        #expect(handler.world.agents["new-agent"] != nil)
        #expect(handler.world.agents["test-agent"] == nil)
    }
    
    // Test handling invalid message
    @Test func testHandleInvalidMessage() async {
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        // Create invalid JSON data
        let invalidData = "not valid json".data(using: .utf8)!
        
        // Use a semaphore for synchronization instead of XCTest expectations
        let semaphore = DispatchSemaphore(value: 0)
        
        var receivedResponse: Encodable?
        handler.handleMessage(invalidData, from: "test-agent") { response in
            receivedResponse = response
            semaphore.signal()
        }
        
        // Wait for the completion handler with a timeout
        let result = semaphore.wait(timeout: .now() + 1.0)
        #expect(result == .success, "Timed out waiting for response")
        
        // Now check the response after we're sure it's been received
        if let errorResponse = receivedResponse as? Observation.ErrorResponse {
            #expect(errorResponse.error == "Invalid message format")
        } else {
            #expect(false, "Expected error response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling unknown message type
    @Test func testHandleUnknownMessageType() async {
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        // Create unknown message type
        let unknownMessage = ["unknown": "type"]
        let data = try! JSONSerialization.data(withJSONObject: unknownMessage)
        
        // Use a semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        
        var receivedResponse: Encodable?
        handler.handleMessage(data, from: "test-agent") { response in
            receivedResponse = response
            semaphore.signal()
        }
        
        // Wait for the completion handler with a timeout
        let result = semaphore.wait(timeout: .now() + 1.0)
        #expect(result == .success, "Timed out waiting for response")
        
        if let errorResponse = receivedResponse as? Observation.ErrorResponse {
            #expect(errorResponse.error.contains("Unable to parse message"))
        } else {
            #expect(false, "Expected error response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling action message - move
    @Test func testHandleMoveAction() async throws {
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        // Create a move action
        let moveAction: [String: Any] = [
            "action": "move",
            "targetTile": ["x": 6, "y": 5]
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: moveAction)
        
        // Use a semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        
        var receivedResponse: Encodable?
        handler.handleMessage(data, from: "test-agent") { response in
            receivedResponse = response
            semaphore.signal()
        }
        
        // Wait for the completion handler with a timeout
        let result = semaphore.wait(timeout: .now() + 1.0)
        #expect(result == .success, "Timed out waiting for response")
        
        // Verify the agent moved
        if let agent = handler.world.agents["test-agent"] {
            #expect(agent.position.x == 6)
            #expect(agent.position.y == 5)
        } else {
            #expect(false, "Agent not found in world")
        }
        
        // Verify success response type
        if let successResponse = receivedResponse as? SuccessResponse {
            #expect(successResponse.message == "Move successful")
            #expect(successResponse.data?["x"] == "6")
            #expect(successResponse.data?["y"] == "5")
            #expect(successResponse.data?["currentTileType"] == "grass")
        } else {
            #expect(false, "Expected success response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling invalid move action
    @Test func testHandleInvalidMoveAction() async {
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        // Create an invalid move (too far away)
        let invalidMoveAction: [String: Any] = [
            "action": "move",
            "targetTile": ["x": 10, "y": 10] // Too far from (5,5)
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: invalidMoveAction)
        
        // Use a semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        
        var receivedResponse: Encodable?
        handler.handleMessage(data, from: "test-agent") { response in
            receivedResponse = response
            semaphore.signal()
        }
        
        // Wait for the completion handler with a timeout
        let result = semaphore.wait(timeout: .now() + 1.0)
        #expect(result == .success, "Timed out waiting for response")
        
        // Verify the agent did not move
        #expect(handler.world.agents["test-agent"]?.position.x == 5)
        #expect(handler.world.agents["test-agent"]?.position.y == 5)
        
        // Verify error response
        if let errorResponse = receivedResponse as? Observation.ErrorResponse {
            #expect(errorResponse.error.contains("Invalid move"))
        } else {
            #expect(false, "Expected error response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling query message - observation
    @Test func testHandleObservationQuery() async throws {
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        // Create a query for observation
        let queryMessage: [String: Any] = [
            "query": "observation",
            "parameters": ["timeStep": "0"]
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: queryMessage)
        
        // Use a semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        
        var receivedResponse: Encodable?
        handler.handleMessage(data, from: "test-agent") { response in
            receivedResponse = response
            semaphore.signal()
        }
        
        // Wait for the completion handler with a timeout
        let result = semaphore.wait(timeout: .now() + 1.0)
        #expect(result == .success, "Timed out waiting for response")
        
        // Verify success response (not observation, as we changed the behavior)
        if let successResponse = receivedResponse as? SuccessResponse {
            #expect(successResponse.message == "Observations are only sent at timestep changes")
            #expect(successResponse.data?["agentId"] == "test-agent")
        } else {
            #expect(false, "Expected success response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling query message - status
    @Test func testHandleStatusQuery() async {
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        // Create a query for status
        let queryMessage: [String: Any] = [
            "query": "status"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: queryMessage)
        
        // Use a semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        
        var receivedResponse: Encodable?
        handler.handleMessage(data, from: "test-agent") { response in
            receivedResponse = response
            semaphore.signal()
        }
        
        // Wait for the completion handler with a timeout
        let result = semaphore.wait(timeout: .now() + 1.0)
        #expect(result == .success, "Timed out waiting for response")
        
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
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        // Create a ping system message
        let systemMessage: [String: Any] = [
            "system": "ping"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: systemMessage)
        
        // Use a semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        
        var receivedResponse: Encodable?
        handler.handleMessage(data, from: "test-agent") { response in
            receivedResponse = response
            semaphore.signal()
        }
        
        // Wait for the completion handler with a timeout
        let result = semaphore.wait(timeout: .now() + 1.0)
        #expect(result == .success, "Timed out waiting for response")
        
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
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        // Create an info system message
        let systemMessage: [String: Any] = [
            "system": "info"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: systemMessage)
        
        // Use a semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        
        var receivedResponse: Encodable?
        handler.handleMessage(data, from: "test-agent") { response in
            receivedResponse = response
            semaphore.signal()
        }
        
        // Wait for the completion handler with a timeout
        let result = semaphore.wait(timeout: .now() + 1.0)
        #expect(result == .success, "Timed out waiting for response")
        
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
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        // Create an unknown system message
        let systemMessage: [String: Any] = [
            "system": "unknown_command"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: systemMessage)
        
        // Use a semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        
        var receivedResponse: Encodable?
        handler.handleMessage(data, from: "test-agent") { response in
            receivedResponse = response
            semaphore.signal()
        }
        
        // Wait for the completion handler with a timeout
        let result = semaphore.wait(timeout: .now() + 1.0)
        #expect(result == .success, "Timed out waiting for response")
        
        // Verify error response
        if let errorResponse = receivedResponse as? Observation.ErrorResponse {
            #expect(errorResponse.error.contains("Unknown system command"))
        } else {
            #expect(false, "Expected error response but got something else: \(String(describing: receivedResponse))")
        }
    }
    
    // Test handling interact action (which is not implemented yet)
    @Test func testHandleInteractAction() async {
        let world = createTestWorld()
        let handler = AgentMessageHandler(world: world)
        
        // Create an interact action
        let interactAction: [String: Any] = [
            "action": "interact",
            "target": "resource"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: interactAction)
        
        // Use a semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        
        var receivedResponse: Encodable?
        handler.handleMessage(data, from: "test-agent") { response in
            receivedResponse = response
            semaphore.signal()
        }
        
        // Wait for the completion handler with a timeout
        let result = semaphore.wait(timeout: .now() + 1.0)
        #expect(result == .success, "Timed out waiting for response")
        
        // Verify not-implemented error response
        if let errorResponse = receivedResponse as? Observation.ErrorResponse {
            #expect(errorResponse.error.contains("Interact action not yet implemented"))
        } else {
            #expect(false, "Expected error response but got something else: \(String(describing: receivedResponse))")
        }
    }
}