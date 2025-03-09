//
//  ConnectionHandler.swift
//  AgentWorld
//
//  Created by Claude on 3/9/25.
//

import Foundation
import Network
import OSLog

class ConnectionHandler: CustomStringConvertible {
    private let logger = AppLogger(category: "ConnectionHandler")
    private var connection: ConnectionProtocol
    private let agentId: String
    private weak var manager: ServerConnectionManager?
    
    var description: String {
        return "ConnectionHandler for agent: \(agentId)"
    }
    
    init(connection: ConnectionProtocol, agentId: String, manager: ServerConnectionManager) {
        self.connection = connection
        self.agentId = agentId
        self.manager = manager
    }
    
    func start(queue: DispatchQueue) {
        setupStateHandler()
        connection.start(queue: queue)
        logger.info("Started connection for agent: \(agentId)")
    }
    
    func setupStateHandler() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                self.logger.info("Connection \(self.agentId) ready")
                self.onConnectionReady()
            case .failed(let error):
                self.logger.error("Connection \(self.agentId) failed: \(error.localizedDescription)")
                self.manager?.removeAgent(self.agentId)
            case .cancelled:
                self.logger.info("Connection \(self.agentId) cancelled")
                self.manager?.removeAgent(self.agentId)
            default:
                break
            }
        }
    }
    
    private func onConnectionReady() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let manager = self.manager else { return }
            
            // Place the agent in the world at a random valid location
            if let position = manager.placeAgentInWorld(self.agentId) {
                self.logger.info("Placed agent \(self.agentId) at position (\(position.x), \(position.y))")
                
                // Start receiving messages from this agent
                self.receiveMessage()
            }
        }
    }
    
    func receiveMessage() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Error receiving data from \(self.agentId): \(error.localizedDescription)")
                self.manager?.removeAgent(self.agentId)
                return
            }
            
            if let data = data, !data.isEmpty {
                // Process the received data through the manager
                self.manager?.handleReceivedMessage(data, from: self.agentId)
                
                // Continue receiving messages only if manager still exists
                // This prevents a potential loop if the agent is being removed
                if self.manager != nil {
                    self.receiveMessage()
                }
            } else if isComplete {
                self.logger.info("Connection \(self.agentId) closed by remote peer")
                self.manager?.removeAgent(self.agentId)
            }
        }
    }
    
    func send<T: Encodable>(_ message: T, completion: @escaping (Error?) -> Void) {
        do {
            let jsonData = try JSONEncoder().encode(message)
            connection.send(content: jsonData) { error in
                if let error = error {
                    self.logger.error("Error sending message to \(self.agentId): \(error.localizedDescription)")
                    completion(error)
                } else {
                    completion(nil)
                }
            }
        } catch {
            logger.error("Error encoding message for \(agentId): \(error.localizedDescription)")
            completion(error)
        }
    }
    
    func cancel() {
        connection.cancel()
    }
}