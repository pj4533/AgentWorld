//
//  MockNetworkClasses.swift
//  AgentWorldTests
//
//  Created by Claude on 3/9/25.
//

import Foundation
import Network
@testable import AgentWorld

// Mock delegate to capture and verify calls
class MockServerConnectionManagerDelegate: ServerConnectionManagerDelegate {
    var worldDidUpdateCalled = false
    var agentDidConnectCalled = false
    var agentDidDisconnectCalled = false
    var serverDidEncounterErrorCalled = false
    
    var lastUpdatedWorld: World?
    var lastConnectedAgentId: String?
    var lastConnectedAgentPosition: (x: Int, y: Int)?
    var lastDisconnectedAgentId: String?
    var lastError: Error?
    
    // Callbacks for signaling test completions
    var onWorldDidUpdate: ((World) -> Void)?
    var onAgentDidConnect: ((String) -> Void)?
    var onAgentDidDisconnect: ((String) -> Void)?
    var onServerDidEncounterError: ((Error) -> Void)?
    
    // Reset all tracked state
    func reset() {
        worldDidUpdateCalled = false
        agentDidConnectCalled = false
        agentDidDisconnectCalled = false
        serverDidEncounterErrorCalled = false
        
        lastUpdatedWorld = nil
        lastConnectedAgentId = nil
        lastConnectedAgentPosition = nil
        lastDisconnectedAgentId = nil
        lastError = nil
        
        onWorldDidUpdate = nil
        onAgentDidConnect = nil
        onAgentDidDisconnect = nil
        onServerDidEncounterError = nil
    }
    
    func worldDidUpdate(_ world: World) {
        worldDidUpdateCalled = true
        lastUpdatedWorld = world
        
        // Call callback if registered
        if let callback = onWorldDidUpdate {
            callback(world)
        }
    }
    
    func agentDidConnect(id: String, position: (x: Int, y: Int)) {
        agentDidConnectCalled = true
        lastConnectedAgentId = id
        lastConnectedAgentPosition = position
        
        // Call callback if registered
        if let callback = onAgentDidConnect {
            callback(id)
        }
    }
    
    func agentDidDisconnect(id: String) {
        agentDidDisconnectCalled = true
        lastDisconnectedAgentId = id
        
        // Call callback if registered
        if let callback = onAgentDidDisconnect {
            callback(id)
        }
    }
    
    func serverDidEncounterError(_ error: Error) {
        serverDidEncounterErrorCalled = true
        lastError = error
        
        // Call callback if registered
        if let callback = onServerDidEncounterError {
            callback(error)
        }
    }
}

// Mock Network Factory for isolation in tests
class MockNetworkFactory: NetworkFactory {
    var lastCreatedListener: MockListener?
    var lastCreatedConnection: MockConnection?
    var shouldFailListenerCreation = false
    var onHandlerCreated: ((ConnectionProtocol) -> Void)?
    
    // Custom implementation for tests to override default behavior
    var createListenerImpl: ((NWParameters, NWEndpoint.Port) throws -> ListenerProtocol)?
    
    // Reset all state for clean test isolation
    func reset() {
        lastCreatedListener = nil
        lastCreatedConnection = nil
        shouldFailListenerCreation = false
        onHandlerCreated = nil
        createListenerImpl = nil
        
        // Ensure any existing instances are also reset to prevent state leaks
        lastCreatedListener?.reset()
        lastCreatedConnection?.reset()
    }
    
    func createListener(using parameters: NWParameters, on port: NWEndpoint.Port) throws -> ListenerProtocol {
        // If a custom implementation is provided for testing, use that
        if let customImpl = createListenerImpl {
            return try customImpl(parameters, port)
        }
        
        // Otherwise use the default implementation
        if shouldFailListenerCreation {
            throw NSError(domain: "MockNetworkFactory", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create listener (test mode)"])
        }
        
        let listener = MockListener(port: port.rawValue)
        lastCreatedListener = listener
        return listener
    }
    
    func createHandler(for connection: NWConnection) -> ConnectionProtocol {
        let handler = MockConnection()
        lastCreatedConnection = handler
        
        // Notify via callback if registered
        if let onHandlerCreated = onHandlerCreated {
            onHandlerCreated(handler)
        }
        
        return handler
    }
}

// Mock Listener for testing
class MockListener: ListenerProtocol {
    var newConnectionHandler: ((NWConnection) -> Void)?
    var stateUpdateHandler: ((NWListener.State) -> Void)?
    var port: NWEndpoint.Port?
    var shouldFailOnStart = false
    private var connectionId: UUID = UUID()
    
    init(port: UInt16 = 8000) {
        self.port = NWEndpoint.Port(rawValue: port)
    }
    
    // Reset all state for clean test isolation
    func reset() {
        newConnectionHandler = nil
        stateUpdateHandler = nil
        shouldFailOnStart = false
        connectionId = UUID() // Generate a new unique ID
    }
    
    func start(queue: DispatchQueue) {
        if shouldFailOnStart {
            stateUpdateHandler?(.failed(NWError.posix(.ECONNREFUSED)))
        } else {
            // Immediately move to ready state
            stateUpdateHandler?(.ready)
        }
    }
    
    // Default implementation
    func cancel() {
        // Default behavior - move to cancelled state
        stateUpdateHandler?(.cancelled)
    }
    
    // Helper functions for testing
    func simulateIncomingConnection() {
        // Create a mock connection and notify handler
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("127.0.0.1"), port: port ?? NWEndpoint.Port(rawValue: 8000)!)
        let params = NWParameters.tcp
        let mockNWConnection = NWConnection(to: endpoint, using: params)
        newConnectionHandler?(mockNWConnection)
    }
    
    func simulateFailure() {
        stateUpdateHandler?(.failed(NWError.posix(.ECONNREFUSED)))
    }
}

// Mock Connection for testing
class MockConnection: ConnectionProtocol {
    var stateUpdateHandler: ((NWConnection.State) -> Void)?
    var receivedData: Data?
    var sentData: [Data] = []
    var shouldFailSend = false
    var shouldFailReceive = false
    var receiveCompletionData: Data?
    var onReceive: ((Int, Int, @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void) -> Void)?
    var onStart: ((DispatchQueue) -> Void)?
    var onSend: ((Data, @escaping (NWError?) -> Void) -> Void)?
    private var connectionId: UUID = UUID()
    
    // Reset all state for clean test isolation
    func reset() {
        stateUpdateHandler = nil
        receivedData = nil
        sentData = []
        shouldFailSend = false
        shouldFailReceive = false
        receiveCompletionData = nil
        onReceive = nil
        onStart = nil
        onSend = nil
        connectionId = UUID() // Generate a new unique ID
    }
    
    func start(queue: DispatchQueue) {
        // Call the onStart callback if set
        if let onStart = onStart {
            onStart(queue)
        }
        
        // Simulate connection becoming ready
        stateUpdateHandler?(.ready)
    }
    
    func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void) {
        if shouldFailReceive {
            let error = NWError.posix(.ECONNREFUSED)
            completion(nil, nil, false, error)
            return
        }
        
        // Call the onReceive callback if set
        if let onReceive = onReceive {
            onReceive(minimumIncompleteLength, maximumLength, completion)
            return
        }
        
        // Return test data if set, otherwise empty data with no error
        completion(receiveCompletionData, nil, receiveCompletionData == nil, nil)
    }
    
    func send(content: Data, completion: @escaping (NWError?) -> Void) {
        sentData.append(content)
        receivedData = content
        
        // Call the onSend callback if set
        if let onSend = onSend {
            onSend(content, completion)
            return
        }
        
        if shouldFailSend {
            let error = NWError.posix(.ECONNREFUSED)
            completion(error)
        } else {
            // Simulate successful send
            completion(nil)
        }
    }
    
    func cancel() {
        // Simulate connection cancelled
        stateUpdateHandler?(.cancelled)
    }
    
    // Helper functions for testing
    func simulateFailure() {
        stateUpdateHandler?(.failed(NWError.posix(.ECONNREFUSED)))
    }
    
    func simulateIncomingMessage(_ data: Data) {
        receiveCompletionData = data
    }
}