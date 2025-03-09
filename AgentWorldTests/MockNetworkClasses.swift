//
//  MockNetworkClasses.swift
//  AgentWorldTests
//
//  Created by Claude on 3/9/25.
//

import Foundation
import Network
@testable import AgentWorld

// Mock Network Factory for isolation in tests
class MockNetworkFactory: NetworkFactory {
    func createListener(using parameters: NWParameters, on port: NWEndpoint.Port) throws -> ListenerProtocol {
        return MockListener()
    }
    
    func createHandler(for connection: NWConnection) -> ConnectionProtocol {
        return MockConnection()
    }
}

// Mock Listener for testing
class MockListener: ListenerProtocol {
    var newConnectionHandler: ((NWConnection) -> Void)?
    var stateUpdateHandler: ((NWListener.State) -> Void)?
    var port: NWEndpoint.Port?
    
    func start(queue: DispatchQueue) {
        // Immediately move to ready state
        stateUpdateHandler?(.ready)
    }
    
    func cancel() {
        // Immediately move to cancelled state
        stateUpdateHandler?(.cancelled)
    }
}

// Mock Connection for testing
class MockConnection: ConnectionProtocol {
    var stateUpdateHandler: ((NWConnection.State) -> Void)?
    
    func start(queue: DispatchQueue) {
        // Simulate connection becoming ready
        stateUpdateHandler?(.ready)
    }
    
    func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void) {
        // Return empty data with no error
        completion(nil, nil, true, nil)
    }
    
    func send(content: Data, completion: @escaping (NWError?) -> Void) {
        // Simulate successful send
        completion(nil)
    }
    
    func cancel() {
        // Simulate connection cancelled
        stateUpdateHandler?(.cancelled)
    }
}