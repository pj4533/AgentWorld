//
//  ServerConnectionManager.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation
import Network
import OSLog

// MARK: - Server Connection Manager Delegate Protocol
protocol ServerConnectionManagerDelegate: AnyObject {
    func worldDidUpdate(_ world: World)
    func agentDidConnect(id: String, position: (x: Int, y: Int))
    func agentDidDisconnect(id: String)
    func serverDidEncounterError(_ error: Error)
}

// Optional default implementations
extension ServerConnectionManagerDelegate {
    func agentDidConnect(id: String, position: (x: Int, y: Int)) {}
    func agentDidDisconnect(id: String) {}
    func serverDidEncounterError(_ error: Error) {}
}

// MARK: - Server Connection Manager
class ServerConnectionManager {
    private var listener: ListenerProtocol?
    private let defaultPort: UInt16 = 8000
    private let logger = AppLogger(category: "ServerConnectionManager")
    private let factory: NetworkFactory
    private let messageHandler: AgentMessageHandler
    
    // Dictionary to store active connections
    private var connections: [String: ConnectionProtocol] = [:]
    
    // Delegate to notify observers of world changes
    weak var delegate: ServerConnectionManagerDelegate?
    
    // Reference to the world for agent placement and movement
    var world: World {
        didSet {
            // Keep the messageHandler's world reference in sync
            messageHandler.updateWorld(world)
            
            // Notify delegate of world update
            delegate?.worldDidUpdate(world)
        }
    }
    
    // Initialize with optional custom port, world reference, and factory
    init(port: UInt16? = nil, world: World, factory: NetworkFactory = DefaultNetworkFactory()) {
        self.world = world
        self.factory = factory
        self.messageHandler = AgentMessageHandler(world: world)
        
        // We don't throw from the initializer, but handle errors internally with logging
        do {
            try setupListener(port: port ?? defaultPort)
        } catch {
            logger.error("Failed to initialize server: \(error.localizedDescription)")
            delegate?.serverDidEncounterError(error)
        }
    }
    
    private func setupListener(port: UInt16) throws {
        // Create a TCP listener
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
        
        // Set listener handlers
        setupListenerHandlers()
        
        // Start listening
        listener?.start(queue: .main)
        logger.info("Server started listening on port \(port)")
    }
    
    private func setupListenerHandlers() {
        // Handle new connections
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
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
                // Try to restart after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.listener?.cancel()
                    
                    // Handle setup errors internally
                    do {
                        try self.setupListener(port: self.defaultPort)
                    } catch {
                        self.logger.error("Failed to restart listener: \(error.localizedDescription)")
                        self.delegate?.serverDidEncounterError(error)
                    }
                }
            case .cancelled:
                self.logger.info("Listener cancelled")
            default:
                break
            }
        }
    }
    
    private func handleNewConnection(_ nwConnection: NWConnection) {
        // Generate a unique ID for this agent
        let agentId = "agent-\(UUID().uuidString.prefix(8))"
        
        // Create a connection handler using the factory
        var connection = factory.createHandler(for: nwConnection)
        
        // Store the connection
        connections[agentId] = connection
        
        // Start the connection
        connection.start(queue: .main)
        logger.info("New connection established: \(agentId)")
        
        // Handle connection state updates
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.logger.info("Connection \(agentId) ready")
                
                // Place the agent in the world at a random valid location
                DispatchQueue.main.async {
                    if let position = self.world.placeAgent(id: agentId) {
                        self.logger.info("Placed agent \(agentId) at position (\(position.x), \(position.y))")
                        
                        // Notify delegate of new agent connection
                        self.delegate?.agentDidConnect(id: agentId, position: position)
                        
                        // Send initial observation to the agent
                        if let observation = self.world.createObservation(for: agentId, timeStep: 0) {
                            self.sendMessage(observation, to: agentId)
                        }
                    } else {
                        self.logger.error("Failed to place agent \(agentId) in the world")
                    }
                }
                
                // Start receiving messages from this agent
                self.receiveMessage(from: agentId, connection: connection)
                
            case .failed(let error):
                self.logger.error("Connection \(agentId) failed: \(error.localizedDescription)")
                self.removeConnection(agentId)
            case .cancelled:
                self.logger.info("Connection \(agentId) cancelled")
                self.removeConnection(agentId)
            default:
                break
            }
        }
    }
    
    private func receiveMessage(from agentId: String, connection: ConnectionProtocol) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Error receiving data from \(agentId): \(error.localizedDescription)")
                self.removeConnection(agentId)
                return
            }
            
            if let data = data, !data.isEmpty {
                // Process the received data
                self.messageHandler.handleMessage(data, from: agentId) { response in
                    if let response = response {
                        self.sendMessage(response, to: agentId)
                    }
                }
                
                // Continue receiving messages
                self.receiveMessage(from: agentId, connection: connection)
            } else if isComplete {
                self.logger.info("Connection \(agentId) closed by remote peer")
                self.removeConnection(agentId)
            }
        }
    }
    
    private func sendMessage<T: Encodable>(_ message: T, to agentId: String) {
        guard let connection = connections[agentId] else {
            logger.error("Tried to send message to nonexistent agent: \(agentId)")
            return
        }
        
        do {
            let jsonData = try JSONEncoder().encode(message)
            
            connection.send(content: jsonData) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.logger.error("Error sending message to \(agentId): \(error.localizedDescription)")
                } else {
                    self.logger.debug("Sent message to \(agentId)")
                }
            }
        } catch {
            logger.error("Error encoding message for \(agentId): \(error.localizedDescription)")
        }
    }
    
    private func removeConnection(_ agentId: String) {
        connections[agentId]?.cancel()
        connections.removeValue(forKey: agentId)
        
        // Remove agent from the world
        DispatchQueue.main.async {
            var updatedWorld = self.world
            let removed = updatedWorld.removeAgent(id: agentId)
            
            if removed {
                // Update the world reference with the updated one
                self.world = updatedWorld
                
                // Notify delegate about agent disconnection
                self.delegate?.agentDidDisconnect(id: agentId)
                self.logger.info("Agent \(agentId) successfully removed from world")
            } else {
                self.logger.error("Failed to remove agent \(agentId) from world - agent not found")
            }
        }
        
        logger.info("Removed connection for \(agentId)")
    }
    
    // Updates the world with a new instance
    func updateWorld(_ newWorld: World) {
        self.world = newWorld
    }
    
    // Send observations to all connected agents
    func sendObservationsToAll(timeStep: Int) {
        for agentId in connections.keys {
            if let observation = world.createObservation(for: agentId, timeStep: timeStep) {
                sendMessage(observation, to: agentId)
            }
        }
    }
    
    func stopServer() {
        // Cancel all connections
        for (agentId, connection) in connections {
            connection.cancel()
            logger.info("Cancelled connection for \(agentId)")
        }
        connections.removeAll()
        
        // Cancel the listener
        listener?.cancel()
        logger.info("Server stopped")
    }
    
    deinit {
        stopServer()
    }
}