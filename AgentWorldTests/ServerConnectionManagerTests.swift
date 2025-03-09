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
    
    // MARK: - Helper Methods
    func createTestManager() -> (ServerConnectionManager, World, MockNetworkFactory, MockServerConnectionManagerDelegate) {
        // Create a fresh isolated world for each test to ensure isolation
        let world = World()
        
        // Initialize with known state - grass everywhere
        for y in 0..<World.size {
            for x in 0..<World.size {
                world.tiles[y][x] = .grass
            }
        }
        
        let mockFactory = MockNetworkFactory()
        // Reset mock factory state to ensure clean test isolation
        mockFactory.reset()
        
        let mockDelegate = MockServerConnectionManagerDelegate()
        // Reset mock delegate state to ensure clean test isolation
        mockDelegate.reset()
        
        // Use a unique port for each test instance to avoid conflicts
        // Use a consistent algorithm to generate a deterministic but unique port per test
        let testIdentifier = UUID().uuidString
        let portSeed = testIdentifier.utf8.reduce(0) { $0 + UInt16($1) } 
        let uniquePort: UInt16 = 49152 + (portSeed % 16383)
        
        let serverManager = ServerConnectionManager(port: uniquePort, world: world, factory: mockFactory)
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
        // Create a clean set of isolated test dependencies
        let (serverManager, _, _, mockDelegate) = createTestManager()
        
        // Ensure a clean slate for this test
        mockDelegate.reset()
        
        // Setup notification tracking
        let worldUpdatedSemaphore = DispatchSemaphore(value: 0)
        mockDelegate.onWorldDidUpdate = { _ in
            worldUpdatedSemaphore.signal()
        }
        
        // Create a new isolated world with detectable differences
        let newWorld = World()
        // Set some arbitrary tiles to a specific type to make it distinguishable
        for i in 0..<5 {
            for j in 0..<5 {
                newWorld.tiles[i][j] = .desert
            }
        }
        
        // Act - update the world
        serverManager.updateWorld(newWorld)
        
        // Wait for the delegate to be notified - using a longer timeout for reliability
        let result = worldUpdatedSemaphore.wait(timeout: .now() + 10.0)
        
        // Clear callback to avoid retain cycles
        mockDelegate.onWorldDidUpdate = nil
        
        // Assert
        #expect(result == .success, "Timed out waiting for world update notification")
        #expect(mockDelegate.worldDidUpdateCalled, "Delegate should be notified of world update")
        #expect(mockDelegate.lastUpdatedWorld != nil, "Updated world should be provided to delegate")
        
        // Verify the world was actually updated
        let desertTileCount = (0..<5).flatMap { i in
            (0..<5).filter { j in
                serverManager.world.tiles[i][j] == .desert
            }
        }.count
        
        #expect(desertTileCount > 0, "World should contain updated desert tiles")
    }
    
    @Test
    func testHandleNewConnection() {
        // Create a clean set of isolated test dependencies
        let (serverManager, _, mockFactory, mockDelegate) = createTestManager()
        
        // Ensure a clean slate for this test (reset all tracked state)
        mockFactory.reset()
        mockDelegate.reset()
        
        // Create fresh mocks specific to this test
        let mockListener = MockListener()
        mockFactory.lastCreatedListener = mockListener
        
        // Store a strong reference to the connection that will be created
        var testConnection: MockConnection?
        
        // Customize the factory to track the created connection
        mockFactory.onHandlerCreated = { conn in
            if let mockConn = conn as? MockConnection {
                testConnection = mockConn
            }
        }
        
        // Use a semaphore to track when the agent is connected
        let agentConnectedSemaphore = DispatchSemaphore(value: 0)
        mockDelegate.onAgentDidConnect = { _ in
            agentConnectedSemaphore.signal()
        }
        
        // Act - simulate an incoming connection
        mockListener.simulateIncomingConnection()
        
        // Wait for the agent connected notification with a timeout
        let result = agentConnectedSemaphore.wait(timeout: .now() + 5.0)
        
        // Clear the handler to avoid potential retain cycles
        mockFactory.onHandlerCreated = nil
        mockDelegate.onAgentDidConnect = nil
        
        // Assert
        #expect(result == .success, "Timed out waiting for agent connection")
        #expect(mockDelegate.agentDidConnectCalled, "Agent connection should be reported to delegate")
        #expect(mockDelegate.lastConnectedAgentId != nil, "Agent ID should be provided to delegate")
        #expect(mockFactory.lastCreatedConnection != nil, "A connection should have been created")
    }
    
    @Test
    func testAgentRemoval() {
        // Create a clean set of isolated test dependencies
        let (serverManager, _, mockFactory, mockDelegate) = createTestManager()
        
        // Ensure a clean slate for this test (reset all tracked state)
        mockFactory.reset()
        mockDelegate.reset()
        
        // Create fresh mocks specific to this test
        let mockListener = MockListener()
        mockFactory.lastCreatedListener = mockListener
        
        // Track the created connection
        var testConnection: MockConnection?
        mockFactory.onHandlerCreated = { conn in
            if let mockConn = conn as? MockConnection {
                testConnection = mockConn
            }
        }
        
        // Use a semaphore to track when the agent is connected
        let agentConnectedSemaphore = DispatchSemaphore(value: 0)
        var connectedAgentId: String?
        mockDelegate.onAgentDidConnect = { id in
            connectedAgentId = id
            agentConnectedSemaphore.signal()
        }
        
        // Act - simulate an incoming connection
        mockListener.simulateIncomingConnection()
        
        // Wait for the agent connected notification
        let connectResult = agentConnectedSemaphore.wait(timeout: .now() + 5.0)
        #expect(connectResult == .success, "Timed out waiting for agent connection")
        #expect(connectedAgentId != nil, "Agent should have connected with an ID")
        
        // Reset delegate state to test disconnect separately
        mockDelegate.reset()
        
        // Setup disconnect tracking
        let agentDisconnectedSemaphore = DispatchSemaphore(value: 0)
        mockDelegate.onAgentDidDisconnect = { _ in
            agentDisconnectedSemaphore.signal()
        }
        
        // Act - simulate connection failure for the connected agent
        if let connection = testConnection {
            connection.simulateFailure()
        } else if let connection = mockFactory.lastCreatedConnection {
            connection.simulateFailure()
        } else {
            #expect(false, "No connection was created")
            return
        }
        
        // Wait for agent disconnection - using a longer timeout for reliability
        let disconnectResult = agentDisconnectedSemaphore.wait(timeout: .now() + 10.0)
        
        // Clear callbacks to avoid retain cycles
        mockFactory.onHandlerCreated = nil
        mockDelegate.onAgentDidConnect = nil
        mockDelegate.onAgentDidDisconnect = nil
        
        // Assert
        #expect(disconnectResult == .success, "Timed out waiting for agent disconnection")
        #expect(mockDelegate.agentDidDisconnectCalled, "Delegate should be notified of agent disconnection")
        
        if let removedId = mockDelegate.lastDisconnectedAgentId, let originalId = connectedAgentId {
            #expect(removedId == originalId, "Removed agent ID should match connected agent ID")
        } else {
            #expect(false, "Both agent IDs should be non-nil")
        }
    }
    
    @Test
    func testSendObservationsToAll() {
        // Create a clean set of isolated test dependencies
        let (serverManager, world, mockFactory, mockDelegate) = createTestManager()
        
        // Ensure a clean slate for this test
        mockFactory.reset()
        mockDelegate.reset()
        
        // Create fresh mocks
        let mockListener = MockListener()
        mockFactory.lastCreatedListener = mockListener
        
        // Track the connection that will be created
        var testConnection: MockConnection?
        mockFactory.onHandlerCreated = { conn in
            if let mockConn = conn as? MockConnection {
                testConnection = mockConn
            }
        }
        
        // Use a semaphore to track when the agent is connected
        let agentConnectedSemaphore = DispatchSemaphore(value: 0)
        mockDelegate.onAgentDidConnect = { _ in
            agentConnectedSemaphore.signal()
        }
        
        // Simulate connection and agent placement
        mockListener.simulateIncomingConnection()
        
        // Wait for the agent connected notification
        let connectResult = agentConnectedSemaphore.wait(timeout: .now() + 5.0)
        #expect(connectResult == .success, "Timed out waiting for agent connection")
        
        // Verify at least one agent is in the world
        #expect(serverManager.world.agents.count > 0, "At least one agent should be connected")
        
        // Reset sent data tracking on the connection that was created
        if let connection = testConnection {
            connection.sentData = []
        } else if let connection = mockFactory.lastCreatedConnection {
            connection.sentData = []
        } else {
            #expect(false, "No connection was created")
            return
        }
        
        // Use a semaphore to track when data is sent
        let dataSentSemaphore = DispatchSemaphore(value: 0)
        var capturedData: Data?
        
        // Configure the connection to signal when data is sent
        if let connection = testConnection ?? mockFactory.lastCreatedConnection {
            connection.onSend = { data, completion in
                capturedData = data
                dataSentSemaphore.signal()
                completion(nil)
            }
        }
        
        // Act - send observations with a specific timeStep
        let testTimeStep = 42
        serverManager.sendObservationsToAll(timeStep: testTimeStep)
        
        // Wait for the data to be sent - using a longer timeout for reliability
        let sendResult = dataSentSemaphore.wait(timeout: .now() + 10.0)
        
        // Clean up to avoid retain cycles
        mockFactory.onHandlerCreated = nil
        mockDelegate.onAgentDidConnect = nil
        if let connection = testConnection ?? mockFactory.lastCreatedConnection {
            connection.onSend = nil
        }
        
        // Assert
        #expect(sendResult == .success, "Timed out waiting for observations sending")
        #expect(capturedData != nil, "No data was captured from send operation")
        
        // Verify the connection's sent data was tracked properly
        if let connection = testConnection ?? mockFactory.lastCreatedConnection {
            #expect(connection.sentData.count >= 1, "At least one observation should be sent to the connected agent")
        }
    }
    
    @Test
    func testHandleReceivedMessage() {
        // Create a clean set of isolated test dependencies
        let (serverManager, _, mockFactory, mockDelegate) = createTestManager()
        
        // Ensure a clean slate for this test
        mockFactory.reset()
        mockDelegate.reset()
        
        // Create fresh mocks
        let mockListener = MockListener()
        mockFactory.lastCreatedListener = mockListener
        
        // Track the connection that will be created
        var testConnection: MockConnection?
        mockFactory.onHandlerCreated = { conn in
            if let mockConn = conn as? MockConnection {
                testConnection = mockConn
            }
        }
        
        // Use a semaphore to track when the agent is connected
        let agentConnectedSemaphore = DispatchSemaphore(value: 0)
        var connectedAgentId: String?
        mockDelegate.onAgentDidConnect = { id in
            connectedAgentId = id
            agentConnectedSemaphore.signal()
        }
        
        // Simulate connection and agent placement
        mockListener.simulateIncomingConnection()
        
        // Wait for the agent connected notification - using a longer timeout for reliability
        let connectResult = agentConnectedSemaphore.wait(timeout: .now() + 10.0)
        #expect(connectResult == .success, "Timed out waiting for agent connection")
        #expect(connectedAgentId != nil, "Agent should have connected with an ID")
        
        // Reset sent data tracking
        if let connection = testConnection {
            connection.sentData = []
        } else if let connection = mockFactory.lastCreatedConnection {
            connection.sentData = []
        } else {
            #expect(false, "No connection was created")
            return
        }
        
        // Use a semaphore to track when a response is sent back
        let responseSentSemaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        
        // Configure the connection to signal when data is sent
        if let connection = testConnection ?? mockFactory.lastCreatedConnection {
            connection.onSend = { data, completion in
                responseData = data
                responseSentSemaphore.signal()
                completion(nil)
            }
        }
        
        // Create a test message - a system ping
        let message = ["type": "system", "system": "ping"]
        let messageData: Data
        do {
            messageData = try JSONSerialization.data(withJSONObject: message)
        } catch {
            #expect(false, "Failed to create test data: \(error)")
            return
        }
        
        // Get agent ID - we should now have it from the connection process
        guard let agentId = connectedAgentId ?? serverManager.world.agents.keys.first else {
            #expect(false, "No agent found")
            return
        }
        
        // Act - send the message
        serverManager.handleReceivedMessage(messageData, from: agentId)
        
        // Wait for a response to be sent back - using a longer timeout for reliability
        let responseResult = responseSentSemaphore.wait(timeout: .now() + 10.0)
        
        // Clean up to avoid retain cycles
        mockFactory.onHandlerCreated = nil
        mockDelegate.onAgentDidConnect = nil
        if let connection = testConnection ?? mockFactory.lastCreatedConnection {
            connection.onSend = nil
        }
        
        // Assert
        #expect(responseResult == .success, "Timed out waiting for response to be sent")
        #expect(responseData != nil, "No response data was captured")
        
        // Verify the response data count is correct
        if let connection = testConnection ?? mockFactory.lastCreatedConnection {
            #expect(connection.sentData.count >= 1, "Response should be sent back to agent")
        }
    }
    
    @Test
    func testListenerFailure() {
        // Create a clean set of isolated test dependencies
        let (_, _, mockFactory, mockDelegate) = createTestManager()
        
        // Ensure a clean slate for this test
        mockFactory.reset()
        mockDelegate.reset()
        
        // Create fresh mocks
        let mockListener = MockListener()
        mockFactory.lastCreatedListener = mockListener
        
        // Use a semaphore to track when an error is reported
        let errorReportedSemaphore = DispatchSemaphore(value: 0)
        mockDelegate.onServerDidEncounterError = { _ in
            errorReportedSemaphore.signal()
        }
        
        // Act - simulate listener failure
        mockListener.simulateFailure()
        
        // Wait for the error to be reported - using a longer timeout for reliability
        let result = errorReportedSemaphore.wait(timeout: .now() + 10.0)
        
        // Clean up to avoid retain cycles
        mockDelegate.onServerDidEncounterError = nil
        
        // Assert
        #expect(result == .success, "Timed out waiting for error reporting")
        #expect(mockDelegate.serverDidEncounterErrorCalled, "Server error should be reported to delegate")
        #expect(mockDelegate.lastError != nil, "Error object should be provided to delegate")
    }
}