//
//  MessageServiceTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/9/25.
//

import Foundation
import Testing
import Network
@testable import AgentWorld

@Suite
struct MessageServiceTests {
    
    // MARK: - Tests
    @Test
    func testGetMessageTypeIdentifiesObservation() {
        // Setup
        let messageService = MessageService()
        let testObservation = Observation(
            agent_id: "test-agent",
            currentLocation: Observation.TilePosition(x: 5, y: 5, type: "grass"),
            surroundings: Observation.Surroundings(tiles: [], agents: []),
            timeStep: 1
        )
        
        // Act
        let messageType = messageService.getMessageType(for: testObservation)
        
        // Assert
        #expect(messageType == "observation")
    }
    
    @Test
    func testGetMessageTypeIdentifiesSuccessResponse() {
        // Setup
        let messageService = MessageService()
        let successResponse = SuccessResponse(message: "Success", data: ["key": "value"])
        
        // Act
        let messageType = messageService.getMessageType(for: successResponse)
        
        // Assert
        #expect(messageType == "success")
    }
    
    @Test
    func testGetMessageTypeIdentifiesErrorResponse() {
        // Setup
        let messageService = MessageService()
        let errorResponse = Observation.ErrorResponse(error: "Something went wrong")
        
        // Act
        let messageType = messageService.getMessageType(for: errorResponse)
        
        // Assert
        #expect(messageType == "error")
    }
    
    @Test
    func testSendEncodesAndSendsMessage() {
        // Setup
        let messageService = MessageService()
        let mockConnection = MockConnection()
        let agentId = "test-agent"
        let world = World()
        let mockFactory = MockNetworkFactory()
        let manager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        let connectionHandler = ConnectionHandler(connection: mockConnection, agentId: agentId, manager: manager)
        
        let testMessage = SuccessResponse(message: "Test", data: ["key": "value"])
        var completionCalled = false
        
        // Act
        messageService.send(testMessage, to: agentId, via: connectionHandler) {
            completionCalled = true
        }
        
        // Assert
        #expect(mockConnection.sentData.count == 1)
        #expect(completionCalled)
    }
    
    @Test
    func testVerifyObservationPositionReturnsTrueForMatch() {
        // Setup
        let messageService = MessageService()
        let position = (x: 5, y: 10)
        let agent = AgentInfo(id: "test-agent", position: position, color: .blue)
        
        let observation = Observation(
            agent_id: "test-agent",
            currentLocation: Observation.TilePosition(x: position.x, y: position.y, type: "grass"),
            surroundings: Observation.Surroundings(tiles: [], agents: []),
            timeStep: 1
        )
        
        // Act
        let result = messageService.verifyObservationPosition(observation, agent: agent)
        
        // Assert
        #expect(result)
    }
    
    @Test
    func testVerifyObservationPositionReturnsFalseForMismatch() {
        // Setup
        let messageService = MessageService()
        let position = (x: 5, y: 10)
        let agent = AgentInfo(id: "test-agent", position: position, color: .blue)
        
        let observation = Observation(
            agent_id: "test-agent",
            currentLocation: Observation.TilePosition(x: position.x + 1, y: position.y, type: "grass"),
            surroundings: Observation.Surroundings(tiles: [], agents: []),
            timeStep: 1
        )
        
        // Act
        let result = messageService.verifyObservationPosition(observation, agent: agent)
        
        // Assert
        #expect(!result)
    }
}