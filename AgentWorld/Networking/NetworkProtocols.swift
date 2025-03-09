//
//  NetworkProtocols.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation
import Network

// MARK: - Protocol Definitions
protocol ConnectionProtocol {
    var stateUpdateHandler: ((NWConnection.State) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func cancel()
    func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    func send(content: Data, completion: @escaping (NWError?) -> Void)
}

protocol ListenerProtocol {
    var port: NWEndpoint.Port? { get }
    var newConnectionHandler: ((NWConnection) -> Void)? { get set }
    var stateUpdateHandler: ((NWListener.State) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func cancel()
}

// MARK: - Extensions to conform Network types to protocols
extension NWConnection: ConnectionProtocol {
    // We don't need to add any implementations since NWConnection already has all the methods
    // But to satisfy the compiler, we need to explicitly add the implementation of the send method
    public func send(content: Data, completion: @escaping (NWError?) -> Void) {
        self.send(content: content, contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ error in
            completion(error)
        }))
    }
}
extension NWListener: ListenerProtocol {}

// MARK: - Factory Protocol for creating network objects
protocol NetworkFactory {
    func createListener(using parameters: NWParameters, on port: NWEndpoint.Port) throws -> ListenerProtocol
    func createHandler(for connection: NWConnection) -> ConnectionProtocol
}

// MARK: - Default Network Factory Implementation
class DefaultNetworkFactory: NetworkFactory {
    func createListener(using parameters: NWParameters, on port: NWEndpoint.Port) throws -> ListenerProtocol {
        return try NWListener(using: parameters, on: port)
    }
    
    func createHandler(for connection: NWConnection) -> ConnectionProtocol {
        return connection
    }
}