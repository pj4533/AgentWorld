//
//  ServerConnectionManager.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation
import Network
import OSLog

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

// MARK: - Server Connection Manager
class ServerConnectionManager: ObservableObject {
    private var listener: ListenerProtocol?
    private let defaultPort: UInt16 = 8000
    private let logger = AppLogger(category: "ServerConnectionManager")
    private let factory: NetworkFactory
    
    // Dictionary to store active connections
    private var connections: [String: ConnectionProtocol] = [:]
    
    // Reference to the world for agent placement and movement
    @Published var world: World
    
    // Initialize with optional custom port, world reference, and factory
    init(port: UInt16? = nil, world: World, factory: NetworkFactory = DefaultNetworkFactory()) {
        self.world = world
        self.factory = factory
        
        // We don't throw from the initializer, but handle errors internally with logging
        do {
            try setupListener(port: port ?? defaultPort)
        } catch {
            logger.error("Failed to initialize server: \(error.localizedDescription)")
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
                        
                        // Send initial observation to the agent
                        if let observation = self.world.createObservation(for: agentId, timeStep: 0) {
                            self.sendObservation(observation, to: agentId)
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
                self.processReceivedData(data, from: agentId)
                
                // Continue receiving messages
                self.receiveMessage(from: agentId, connection: connection)
            } else if isComplete {
                self.logger.info("Connection \(agentId) closed by remote peer")
                self.removeConnection(agentId)
            }
        }
    }
    
    private func processReceivedData(_ data: Data, from agentId: String) {
        // Parse the received data as JSON
        if let string = String(data: data, encoding: .utf8) {
            logger.debug("Received from \(agentId): \(string)")
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    logger.info("Processed JSON from \(agentId): \(json)")
                    
                    // Handle agent action commands
                    if let action = json["action"] as? String {
                        switch action {
                        case "move":
                            if let targetTile = json["targetTile"] as? [String: Int],
                               let x = targetTile["x"],
                               let y = targetTile["y"] {
                                handleMoveAction(agentId: agentId, targetX: x, targetY: y)
                            } else {
                                sendError(to: agentId, message: "Invalid target tile format")
                            }
                        default:
                            sendError(to: agentId, message: "Unknown action: \(action)")
                        }
                    }
                }
            } catch {
                logger.error("Error parsing JSON from \(agentId): \(error.localizedDescription)")
                sendError(to: agentId, message: "Invalid JSON format")
            }
        }
    }
    
    private func handleMoveAction(agentId: String, targetX: Int, targetY: Int) {
        DispatchQueue.main.async {
            let success = self.world.moveAgent(id: agentId, to: (x: targetX, y: targetY))
            
            if success {
                self.logger.info("Agent \(agentId) moved to (\(targetX), \(targetY))")
                
                // Notify the agent of success with new observation
                if let observation = self.world.createObservation(for: agentId, timeStep: 0) {
                    self.sendObservation(observation, to: agentId)
                }
            } else {
                self.logger.info("Agent \(agentId) failed to move to (\(targetX), \(targetY))")
                self.sendError(to: agentId, message: "Invalid move - tile is not passable or is occupied")
            }
        }
    }
    
    private func sendObservation(_ observation: Observation, to agentId: String) {
        guard let connection = connections[agentId] else {
            logger.error("Tried to send observation to nonexistent agent: \(agentId)")
            return
        }
        
        do {
            let jsonData = try JSONEncoder().encode(observation)
            
            connection.send(content: jsonData) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.logger.error("Error sending observation to \(agentId): \(error.localizedDescription)")
                } else {
                    self.logger.debug("Sent observation to \(agentId)")
                }
            }
        } catch {
            logger.error("Error encoding observation for \(agentId): \(error.localizedDescription)")
        }
    }
    
    private func sendError(to agentId: String, message: String) {
        guard let connection = connections[agentId] else {
            logger.error("Tried to send error to nonexistent agent: \(agentId)")
            return
        }
        
        let errorResponse = Observation.ErrorResponse(error: message)
        
        do {
            let jsonData = try JSONEncoder().encode(errorResponse)
            
            connection.send(content: jsonData) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.logger.error("Error sending error message to \(agentId): \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Error encoding error message for \(agentId): \(error.localizedDescription)")
        }
    }
    
    private func removeConnection(_ agentId: String) {
        connections[agentId]?.cancel()
        connections.removeValue(forKey: agentId)
        
        // Remove agent from the world
        DispatchQueue.main.async {
            self.world.agents.removeValue(forKey: agentId)
        }
        
        logger.info("Removed connection for \(agentId)")
    }
    
    // Send observations to all connected agents
    func sendObservationsToAll(timeStep: Int) {
        for agentId in connections.keys {
            if let observation = world.createObservation(for: agentId, timeStep: timeStep) {
                sendObservation(observation, to: agentId)
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