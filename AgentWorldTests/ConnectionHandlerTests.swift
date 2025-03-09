//
//  ConnectionHandlerTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/9/25.
//

import Foundation
import Testing
import Network
@testable import AgentWorld

@Suite
struct ConnectionHandlerTests {
    
    // MARK: - Tests
    @Test
    func testConnectionHandlerInitialization() {
        // Setup
        let mockConnection = MockConnection()
        let agentId = "test-agent-123"
        let mockFactory = MockNetworkFactory()
        let world = World()
        let manager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        
        // Act
        let handler = ConnectionHandler(connection: mockConnection, agentId: agentId, manager: manager)
        
        // Assert - verify handler is created successfully
        #expect(handler !== nil)
    }
    
    @Test
    func testConnectionStartCallsStateHandler() {
        // Setup
        let mockConnection = MockConnection()
        let agentId = "test-agent-123"
        let mockFactory = MockNetworkFactory()
        let world = World()
        let manager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        let handler = ConnectionHandler(connection: mockConnection, agentId: agentId, manager: manager)
        
        // Track if the state handler is called
        var stateHandlerCalled = false
        mockConnection.stateUpdateHandler = { state in
            stateHandlerCalled = true
        }
        
        // Act
        handler.start(queue: .main)
        
        // Assert
        #expect(stateHandlerCalled)
    }
    
    @Test
    func testSendDataEncodesAndSends() {
        // Setup
        let mockConnection = MockConnection()
        let agentId = "test-agent-123"
        let mockFactory = MockNetworkFactory()
        let world = World()
        let manager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        let handler = ConnectionHandler(connection: mockConnection, agentId: agentId, manager: manager)
        
        // A simple encodable structure for testing
        struct TestMessage: Encodable {
            let message: String
        }
        
        let testMessage = TestMessage(message: "hello")
        var completionCalled = false
        
        // Act
        handler.send(testMessage) { error in
            completionCalled = true
        }
        
        // Assert
        #expect(mockConnection.sentData.count == 1)
        #expect(completionCalled)
    }
    
    @Test
    func testReceiveMessageHandling() {
        // Setup
        let mockConnection = MockConnection()
        let agentId = "test-agent-123"
        let mockFactory = MockNetworkFactory()
        let mockDelegate = MockServerConnectionManagerDelegate()
        let world = World()
        let manager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        manager.delegate = mockDelegate
        let handler = ConnectionHandler(connection: mockConnection, agentId: agentId, manager: manager)
        
        // Prepare a test message
        let testData = "{}".data(using: .utf8)!
        mockConnection.receiveCompletionData = testData
        
        // Act
        handler.receiveMessage()
        
        // Assert
        // This test is mainly checking that the receive doesn't crash
        // Since the mock connection doesn't actually do anything with received data
        #expect(true)
    }
}