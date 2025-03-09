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
    }
    
    func worldDidUpdate(_ world: World) {
        worldDidUpdateCalled = true
        lastUpdatedWorld = world
    }
    
    func agentDidConnect(id: String, position: (x: Int, y: Int)) {
        agentDidConnectCalled = true
        lastConnectedAgentId = id
        lastConnectedAgentPosition = position
    }
    
    func agentDidDisconnect(id: String) {
        agentDidDisconnectCalled = true
        lastDisconnectedAgentId = id
    }
    
    func serverDidEncounterError(_ error: Error) {
        serverDidEncounterErrorCalled = true
        lastError = error
    }
}

// Mock Network Factory for isolation in tests
class MockNetworkFactory: NetworkFactory {
    var lastCreatedListener: MockListener?
    var lastCreatedConnection: MockConnection?
    var shouldFailListenerCreation = false
    
    func createListener(using parameters: NWParameters, on port: NWEndpoint.Port) throws -> ListenerProtocol {
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
        return handler
    }
}

// Mock Listener for testing
class MockListener: ListenerProtocol {
    var newConnectionHandler: ((NWConnection) -> Void)?
    var stateUpdateHandler: ((NWListener.State) -> Void)?
    var port: NWEndpoint.Port?
    var shouldFailOnStart = false
    
    init(port: UInt16 = 8000) {
        self.port = NWEndpoint.Port(rawValue: port)
    }
    
    func start(queue: DispatchQueue) {
        if shouldFailOnStart {
            stateUpdateHandler?(.failed(NWError.posix(.ECONNREFUSED)))
        } else {
            // Immediately move to ready state
            stateUpdateHandler?(.ready)
        }
    }
    
    func cancel() {
        // Immediately move to cancelled state
        stateUpdateHandler?(.cancelled)
    }
    
    // Helper functions for testing
    func simulateIncomingConnection() {
        // Create a mock connection and notify handler
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("127.0.0.1"), port: NWEndpoint.Port(rawValue: 8000)!)
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
    
    func start(queue: DispatchQueue) {
        // Simulate connection becoming ready
        stateUpdateHandler?(.ready)
    }
    
    func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void) {
        if shouldFailReceive {
            let error = NWError.posix(.ECONNREFUSED)
            completion(nil, nil, false, error)
            return
        }
        
        // Return test data if set, otherwise empty data with no error
        completion(receiveCompletionData, nil, receiveCompletionData == nil, nil)
    }
    
    func send(content: Data, completion: @escaping (NWError?) -> Void) {
        sentData.append(content)
        receivedData = content
        
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