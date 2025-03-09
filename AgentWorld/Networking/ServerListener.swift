//
//  ServerListener.swift
//  AgentWorld
//
//  Created by Claude on 3/9/25.
//

import Foundation
import Network
import OSLog

class ServerListener {
    private let logger = AppLogger(category: "ServerListener")
    // Make listener internal for testing
    internal var listener: ListenerProtocol?
    private let factory: NetworkFactory
    private weak var manager: ServerConnectionManager?
    
    init(factory: NetworkFactory, manager: ServerConnectionManager) {
        self.factory = factory
        self.manager = manager
    }
    
    func start(port: UInt16) throws {
        // Create a TCP listener with appropriate parameters
        let tcpOptions = NWProtocolTCP.Options()
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        
        // Set parameters to allow connections from any interface
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true
        
        // Create the listener with the specified port
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            let error = NSError(domain: "ServerConnectionManager", code: 1, 
                               userInfo: [NSLocalizedDescriptionKey: "Failed to create port from value: \(port)"])
            logger.error("Failed to create port from value: \(port)")
            throw error
        }
        
        // Create the listener and handle potential errors
        listener = try factory.createListener(using: parameters, on: nwPort)
        
        // Set up handlers
        setupHandlers()
        
        // Start listening
        listener?.start(queue: .main)
        logger.info("Server started listening on port \(port)")
    }
    
    private func setupHandlers() {
        // Handle new connections
        listener?.newConnectionHandler = { [weak self] connection in
            self?.manager?.handleNewConnection(connection)
        }
        
        // Handle listener state changes
        listener?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                if let port = self.listener?.port {
                    self.logger.info("Listener ready on port \(port.rawValue)")
                }
            case .failed(let error):
                self.logger.error("Listener failed: \(error.localizedDescription)")
                self.handleListenerFailure(error)
            case .cancelled:
                self.logger.info("Listener cancelled")
            default:
                break
            }
        }
    }
    
    private func handleListenerFailure(_ error: Error) {
        // Notify manager about the failure
        manager?.handleServerError(error)
        
        // Only attempt restart if manager is still valid
        guard let manager = manager else { return }
        
        // Cancel current listener
        listener?.cancel()
        listener = nil
        
        // Try to restart after a delay, but only once
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self, self.listener == nil else { return }
            
            // Try to restart listener
            if let port = NWEndpoint.Port(rawValue: 8000)?.rawValue {
                do {
                    try self.start(port: port)
                } catch {
                    self.logger.error("Failed to restart listener: \(error.localizedDescription)")
                    self.manager?.handleServerError(error)
                }
            }
        }
    }
    
    func stop() {
        listener?.cancel()
    }
}