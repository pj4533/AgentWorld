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
    private let defaultPort: UInt16 = 8000
    private let logger = AppLogger(category: "ServerConnectionManager")
    private let factory: NetworkFactory
    private let messageHandler: AgentMessageHandler
    private let messageService = MessageService()
    
    private var serverListener: ServerListener!
    private var connectionHandlers: [String: ConnectionHandler] = [:]
    
    // Delegate to notify observers of world changes
    weak var delegate: ServerConnectionManagerDelegate? {
        didSet {
            // Pass the delegate to the message handler
            messageHandler.delegate = delegate
        }
    }
    
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
        
        // Create the server listener component
        self.serverListener = ServerListener(factory: factory, manager: self)
        
        // Start the server listener
        do {
            try serverListener.start(port: port ?? defaultPort)
        } catch {
            logger.error("Failed to initialize server: \(error.localizedDescription)")
            delegate?.serverDidEncounterError(error)
        }
    }
    
    // Handle a new incoming connection from the server listener
    func handleNewConnection(_ nwConnection: NWConnection) {
        // Generate a unique ID for this agent
        let agentId = "agent-\(UUID().uuidString.prefix(8))"
        
        // Create a connection handler using the factory
        let connection = factory.createHandler(for: nwConnection)
        let handler = ConnectionHandler(connection: connection, agentId: agentId, manager: self)
        
        // Store the connection handler
        connectionHandlers[agentId] = handler
        
        // Set up the state handler and start the connection
        handler.setupStateHandler()
        handler.start(queue: .main)
        
        logger.info("New connection established: \(agentId)")
    }
    
    // Place an agent in the world and send initial observation
    func placeAgentInWorld(_ agentId: String) -> (x: Int, y: Int)? {
        guard let position = world.placeAgent(id: agentId) else {
            logger.error("Failed to place agent \(agentId) in the world")
            return nil
        }
        
        // Notify delegate of new agent connection
        delegate?.agentDidConnect(id: agentId, position: position)
        
        // Send initial observation to the agent
        if let observation = world.createObservation(for: agentId, timeStep: 0),
           let handler = connectionHandlers[agentId] {
            messageService.send(observation, to: agentId, via: handler)
        }
        
        return position
    }
    
    // Handle a message received from an agent
    func handleReceivedMessage(_ data: Data, from agentId: String) {
        messageHandler.handleMessage(data, from: agentId) { [weak self] response in
            guard let self = self, let response = response else { return }
            self.sendEncodableMessage(response, to: agentId)
        }
    }
    
    // Send a message to a specific agent
    private func sendEncodableMessage<T: Encodable>(_ message: T, to agentId: String) {
        guard let handler = connectionHandlers[agentId] else {
            logger.error("Tried to send message to nonexistent agent: \(agentId)")
            return
        }
        
        messageService.send(message, to: agentId, via: handler)
    }
    
    // Remove an agent from the system
    func removeAgent(_ agentId: String) {
        // Cancel and remove the connection handler
        connectionHandlers[agentId]?.cancel()
        connectionHandlers.removeValue(forKey: agentId)
        
        // Remove agent from the world
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let removed = self.world.removeAgent(id: agentId)
            
            if removed {
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
        // Always ensure we're on the main thread for world updates
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateWorld(newWorld)
            }
            return
        }
        
        logger.info("🔄 ServerConnectionManager updating world reference")
        
        // Get counts safely
        let oldAgentCount = world.agents.count
        logger.info("Current agent count: \(oldAgentCount)")
        
        // Compare the world state before the update (safely)
        if !world.agents.isEmpty {
            // Create a local copy to avoid iteration issues
            let oldAgents = world.agents
            for (agentId, agentInfo) in oldAgents {
                // Simplify logging to avoid formatters
                logger.info("Before: Agent \(agentId) at \(agentInfo.position.x), \(agentInfo.position.y)")
            }
        } else {
            logger.info("Before update: No agents in world")
        }
        
        // Update the world reference
        self.world = newWorld
        
        // Verify the new world state (safely)
        let newAgentCount = world.agents.count
        logger.info("After update: World has \(newAgentCount) agents")
        
        if !world.agents.isEmpty {
            // Create a local copy to avoid iteration issues
            let currentAgents = world.agents
            for (agentId, agentInfo) in currentAgents {
                // Simplify logging to avoid formatters
                logger.info("After: Agent \(agentId) at \(agentInfo.position.x), \(agentInfo.position.y)")
            }
        } else {
            logger.info("After update: No agents in world")
        }
    }
    
    // Send observations to all connected agents
    func sendObservationsToAll(timeStep: Int) {
        // Ensure we're on the main thread for consistent world access
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.sendObservationsToAll(timeStep: timeStep)
            }
            return
        }
        
        // Add an obvious log separator for debugging
        logger.info("========== SENDING OBSERVATIONS [TIMESTEP \(timeStep)] ==========")
        
        // Safely get agent count
        let agentCount = world.agents.count
        logger.info("Current world has \(agentCount) agents")
        
        // Log detailed information about all agents for debugging
        if world.agents.isEmpty {
            logger.info("⚠️ NO AGENTS FOUND IN WORLD")
        } else {
            // Make a local copy of agents to prevent collection modification issues
            let agents = world.agents
            for (agentId, agent) in agents {
                // Double-check each agent has a valid position
                let pos = agent.position
                if pos.x >= 0 && pos.x < World.size && pos.y >= 0 && pos.y < World.size {
                    let tileType = world.tiles[pos.y][pos.x]
                    logger.info("✅ Agent \(agentId) at \(pos.x), \(pos.y) on \(tileType.description) tile")
                } else {
                    logger.error("⚠️ Agent \(agentId) has INVALID position: \(pos.x), \(pos.y)")
                }
            }
        }
        
        // Take a local reference of connections at this moment to avoid issues
        // if connections change during processing
        let currentHandlers = self.connectionHandlers
        
        // Process each connected agent
        for (agentId, handler) in currentHandlers {
            // Safely access the agent info from the world
            guard let agent = world.agents[agentId] else {
                logger.error("⚠️ Agent \(agentId) not found in world when creating observation")
                continue
            }
            
            // Create observation directly from the world
            if let observation = world.createObservation(for: agentId, timeStep: timeStep) {
                // Verify the observation's position matches what we expect
                messageService.verifyObservationPosition(observation, agent: agent)
                
                // Log detailed information about what we're sending
                messageService.logObservationDetails(observation, agentId: agentId)
                
                // Send the verified observation
                messageService.send(observation, to: agentId, via: handler)
            } else {
                logger.error("⚠️ Failed to create observation for agent \(agentId)")
            }
        }
        
        logger.info("========== OBSERVATIONS SENT ==========")
    }
    
    // Handle server errors
    func handleServerError(_ error: Error) {
        delegate?.serverDidEncounterError(error)
    }
    
    // Stop the server
    func stopServer() {
        // Cancel all connections
        for (agentId, handler) in connectionHandlers {
            handler.cancel()
            logger.info("Cancelled connection for \(agentId)")
        }
        connectionHandlers.removeAll()
        
        // Stop the listener
        serverListener.stop()
        logger.info("Server stopped")
    }
    
    deinit {
        stopServer()
    }
}