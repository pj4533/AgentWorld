//
//  ServerConnectionManagerTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/8/25.
//

import Foundation
import Testing
import Network
@testable import AgentWorld

@Suite
struct ServerConnectionManagerTests {
    
    // MARK: - Test Properties
    let testPort: UInt16 = 9000
    
    // MARK: - Helper Methods
    func createTestManager() -> (ServerConnectionManager, World, MockNetworkFactory, MockServerConnectionManagerDelegate) {
        let world = World()
        let mockFactory = MockNetworkFactory()
        let mockDelegate = MockServerConnectionManagerDelegate()
        let serverManager = ServerConnectionManager(port: testPort, world: world, factory: mockFactory)
        serverManager.delegate = mockDelegate
        
        return (serverManager, world, mockFactory, mockDelegate)
    }
    
    // MARK: - Tests
    @Test
    func testInitialization() {
        // Create with mock factory to avoid real network connections
        let (serverManager, _, mockFactory, _) = createTestManager()
        
        // Verify the server initializes with empty agents in the world
        #expect(serverManager.world.agents.isEmpty)
        
        // Verify listener was created
        #expect(mockFactory.lastCreatedListener != nil)
    }
    
    @Test
    func testServerStopsCleanly() {
        // Create with mock factory to avoid real network connections
        let (serverManager, _, _, _) = createTestManager()
        
        // Just test that stopServer doesn't crash
        serverManager.stopServer()
        #expect(true)
    }
    
    @Test
    func testDelegateWorldUpdateNotification() {
        // Setup
        let (serverManager, _, _, mockDelegate) = createTestManager()
        
        // Create a new world
        let newWorld = World()
        
        // Set some arbitrary difference to detect
        for i in 0..<5 {
            for j in 0..<5 {
                newWorld.tiles[i][j] = .desert
            }
        }
        
        // Act
        serverManager.updateWorld(newWorld)
        
        // Assert
        #expect(mockDelegate.worldDidUpdateCalled)
        #expect(mockDelegate.lastUpdatedWorld !== nil)
    }
    
    @Test
    func testHandleNewConnection() {
        // Setup
        let (serverManager, _, mockFactory, mockDelegate) = createTestManager()
        
        // Act - simulate an incoming connection
        if let listener = mockFactory.lastCreatedListener {
            listener.simulateIncomingConnection()
        }
        
        // Delay slightly to allow async operations to complete
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            semaphore.signal()
        }
        
        // Wait for the semaphore with a timeout
        let result = semaphore.wait(timeout: .now() + 0.5)
        #expect(result == .success, "Timed out waiting for connection processing")
        
        // Assert
        #expect(mockFactory.lastCreatedConnection != nil)
        
        // The connection state handler should have been called to change to .ready
        // which would trigger agent placement
        #expect(mockDelegate.agentDidConnectCalled)
        #expect(mockDelegate.lastConnectedAgentId != nil)
    }
    
    @Test
    func testAgentRemoval() {
        // Setup
        let (serverManager, _, mockFactory, mockDelegate) = createTestManager()
        
        // Simulate connection and agent placement
        if let listener = mockFactory.lastCreatedListener {
            listener.simulateIncomingConnection()
        }
        
        // Need to wait for async agent placement
        let semaphore1 = DispatchSemaphore(value: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            semaphore1.signal()
        }
        let result1 = semaphore1.wait(timeout: .now() + 0.5)
        #expect(result1 == .success, "Timed out waiting for agent placement")
        
        // Get agent ID (should be in delegate)
        let agentId = mockDelegate.lastConnectedAgentId
        #expect(agentId != nil)
        
        // Reset delegate to test disconnect
        mockDelegate.reset()
        
        // Act - simulate connection failure for the connected agent
        if let connection = mockFactory.lastCreatedConnection {
            connection.simulateFailure()
        }
        
        // Need to wait for async agent removal
        let semaphore2 = DispatchSemaphore(value: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            semaphore2.signal()
        }
        let result2 = semaphore2.wait(timeout: .now() + 0.5)
        #expect(result2 == .success, "Timed out waiting for agent removal")
        
        // Assert
        #expect(mockDelegate.agentDidDisconnectCalled)
        if let removedId = mockDelegate.lastDisconnectedAgentId, let originalId = agentId {
            #expect(removedId == originalId)
        }
    }
    
    @Test
    func testSendObservationsToAll() {
        // Setup
        let (serverManager, world, mockFactory, _) = createTestManager()
        
        // Simulate connection and agent placement
        if let listener = mockFactory.lastCreatedListener {
            listener.simulateIncomingConnection()
        }
        
        // Need to wait for async agent placement
        let semaphore1 = DispatchSemaphore(value: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            semaphore1.signal()
        }
        let result1 = semaphore1.wait(timeout: .now() + 0.5)
        #expect(result1 == .success, "Timed out waiting for agent placement")
        
        // Reset sent data tracking
        mockFactory.lastCreatedConnection?.sentData = []
        
        // Act
        serverManager.sendObservationsToAll(timeStep: 42)
        
        // Need to wait for async send
        let semaphore2 = DispatchSemaphore(value: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            semaphore2.signal()
        }
        let result2 = semaphore2.wait(timeout: .now() + 0.5)
        #expect(result2 == .success, "Timed out waiting for observations sending")
        
        // Assert
        #expect(mockFactory.lastCreatedConnection?.sentData.count == 1)
    }
    
    @Test
    func testHandleReceivedMessage() {
        // Setup
        let (serverManager, _, mockFactory, _) = createTestManager()
        
        // Simulate connection and agent placement
        if let listener = mockFactory.lastCreatedListener {
            listener.simulateIncomingConnection()
        }
        
        // Need to wait for async agent placement
        let semaphore1 = DispatchSemaphore(value: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            semaphore1.signal()
        }
        let result1 = semaphore1.wait(timeout: .now() + 0.5)
        #expect(result1 == .success, "Timed out waiting for agent placement")
        
        // Reset sent data tracking
        mockFactory.lastCreatedConnection?.sentData = []
        
        // Create a test message - a system ping
        let message = ["type": "system", "system": "ping"]
        let messageData: Data
        do {
            messageData = try JSONSerialization.data(withJSONObject: message)
        } catch {
            #expect(false, "Failed to create test data: \(error)")
            return
        }
        
        // Get agent ID from the connection
        guard let agentId = serverManager.world.agents.keys.first else {
            #expect(false, "No agent found")
            return
        }
        
        // Act
        serverManager.handleReceivedMessage(messageData, from: agentId)
        
        // Need to wait for async processing
        let semaphore2 = DispatchSemaphore(value: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            semaphore2.signal()
        }
        let result2 = semaphore2.wait(timeout: .now() + 0.5)
        #expect(result2 == .success, "Timed out waiting for message handling")
        
        // Assert - should have received a response (pong)
        #expect(mockFactory.lastCreatedConnection?.sentData.count == 1)
    }
    
    @Test
    func testListenerFailure() {
        // Setup
        let (_, _, mockFactory, mockDelegate) = createTestManager()
        
        // Simulate listener failure
        if let listener = mockFactory.lastCreatedListener {
            listener.simulateFailure()
        }
        
        // Need to wait for async error handling
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            semaphore.signal()
        }
        let result = semaphore.wait(timeout: .now() + 0.5)
        #expect(result == .success, "Timed out waiting for error handling")
        
        // Assert - server error should be reported via delegate
        #expect(mockDelegate.serverDidEncounterErrorCalled)
    }
}