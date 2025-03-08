//
//  WorldScene.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit
import OSLog

class WorldScene: SKScene, InputHandlerDelegate, ServerConnectionManagerDelegate {
    private var world: World!
    private var tileSize: CGFloat = 10
    private var worldRenderer: WorldRenderer!
    private var inputHandler: InputHandler!
    private var currentTimeStep: Int = 0
    private var serverConnectionManager: ServerConnectionManager!
    
    private let logger = AppLogger(category: "WorldScene")
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .black
        
        if world == nil {
            // Generate a new world if none was provided
            world = World.generateWorld()
        }
        
        // Calculate tile size based on the view size
        let smallerDimension = min(size.width, size.height)
        tileSize = smallerDimension / CGFloat(World.size)
        
        // Initialize components
        worldRenderer = WorldRenderer(world: world, tileSize: tileSize)
        inputHandler = InputHandler(delegate: self)
        serverConnectionManager = ServerConnectionManager(world: world)
        serverConnectionManager.delegate = self
        
        // Render the world
        worldRenderer.renderWorld(in: self)
    }
    
    func setWorld(_ newWorld: World) {
        world = newWorld
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Game loop updates would go here
    }
    
    // MARK: - Input Handling
    
    override func mouseDown(with event: NSEvent) {
        inputHandler.handleMouseDown(with: event, in: self)
    }
    
    func inputHandler(_ handler: InputHandler, didClickAtPosition position: CGPoint) {
        // Handle click events from input handler
        // This could be expanded for handling different types of interactions
    }
    
    // MARK: - Time Step Handling
    
    /// Update the world state based on a new time step
    func updateToTimeStep(_ timeStep: Int) {
        // Only process if time step has actually changed
        if timeStep > currentTimeStep {
            // Calculate how many steps to advance
            let stepsToAdvance = timeStep - currentTimeStep
            
            // Update the world for each step (this will be where simulation logic happens)
            for _ in 0..<stepsToAdvance {
                simulateOneTimeStep()
            }
            
            // Update internal time step
            currentTimeStep = timeStep
            
            // Re-render the world with updated state
            worldRenderer.renderWorld(in: self)
        }
    }
    
    /// Simulate a single time step in the world
    private func simulateOneTimeStep() {
        // Increment the current time step
        let nextTimeStep = currentTimeStep + 1
        
        // Send updated observations to all connected agents
        serverConnectionManager.sendObservationsToAll(timeStep: nextTimeStep)
        
        // Log the simulation step
        logger.info("Simulating time step: \(nextTimeStep)")
        
        // Update the UI with new agent positions
        DispatchQueue.main.async {
            // Update the world reference in the renderer to reflect changes
            self.worldRenderer = WorldRenderer(world: self.world, tileSize: self.tileSize)
            
            // Re-render the world with the updated agent positions
            self.worldRenderer.renderWorld(in: self)
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the current time step in the world
    func getCurrentTimeStep() -> Int {
        return currentTimeStep
    }
    
    func regenerateWorld() {
        // Stop the current server first
        serverConnectionManager.stopServer()
        
        // Generate a new world
        world = World.generateWorld()
        
        // Create a new server connection manager with the new world
        serverConnectionManager = ServerConnectionManager(world: world)
        serverConnectionManager.delegate = self
        
        // Create a new WorldRenderer with a fresh cache
        worldRenderer = WorldRenderer(world: world, tileSize: tileSize)
        worldRenderer.renderWorld(in: self)
        
        // Reset time step when regenerating world
        currentTimeStep = 0
    }
    
    // MARK: - ServerConnectionManagerDelegate
    
    func worldDidUpdate(_ updatedWorld: World) {
        // The world has been updated, so update the renderer and redraw
        self.world = updatedWorld
        
        // Re-render only when needed
        DispatchQueue.main.async {
            self.worldRenderer.renderWorld(in: self)
        }
    }
    
    func agentDidConnect(id: String, position: (x: Int, y: Int)) {
        logger.info("Agent connected: \(id) at position (\(position.x), \(position.y))")
        
        // Debug logging to verify the agent was added to the world data
        if let agent = world.agents[id] {
            logger.info("✅ Agent \(id) successfully added to world at (\(agent.position.x), \(agent.position.y))")
        } else {
            logger.error("❌ Agent \(id) not found in world data after connection!")
        }
        
        // Create a new WorldRenderer to ensure it has fresh data
        DispatchQueue.main.async {
            // Explicitly recreate the renderer to ensure it sees the updated world
            self.worldRenderer = WorldRenderer(world: self.world, tileSize: self.tileSize)
            self.worldRenderer.renderWorld(in: self)
            
            // Debug - log all agents in the world after rendering
            for (agentId, agent) in self.world.agents {
                self.logger.info("After render: Agent \(agentId) in world at position (\(agent.position.x), \(agent.position.y))")
            }
        }
    }
    
    func agentDidDisconnect(id: String) {
        logger.info("Agent disconnected: \(id)")
        
        // Re-render to remove the agent
        DispatchQueue.main.async {
            self.worldRenderer.renderWorld(in: self)
        }
    }
    
    func serverDidEncounterError(_ error: Error) {
        logger.error("Server error: \(error.localizedDescription)")
    }
}