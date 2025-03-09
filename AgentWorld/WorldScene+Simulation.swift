//
//  WorldScene+Simulation.swift
//  AgentWorld
//
//  Created by Claude on 3/9/25.
//

import SpriteKit

// Extension to handle time step and simulation functionality
extension WorldScene {
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
        
        // Add clear marker for debugging logs
        logger.info("=====================================================")
        logger.info("🔄 TIMESTEP \(nextTimeStep) STARTING")
        logger.info("=====================================================")
        
        synchronizeWorldState(nextTimeStep: nextTimeStep)
        
        logger.info("=====================================================")
        logger.info("🔄 TIMESTEP \(nextTimeStep) COMPLETED")
        logger.info("=====================================================")
    }
    
    // Helper method to synchronize the world state from the server
    private func synchronizeWorldState(nextTimeStep: Int) {
        // CRITICAL FIX #1: The ServerConnectionManager has the authoritative world state
        // Since it's the component that receives agent move commands and updates their positions
        let authoritative = serverConnectionManager.world
        
        // Log world state from server for verification
        logger.info("🌍 Agent positions in ServerConnectionManager's world:")
        for (agentId, agent) in authoritative.agents {
            logger.info("Agent \(agentId) at (\(agent.position.x), \(agent.position.y))")
        }
        
        // CRITICAL FIX #2: Always use the server's world for our local state
        // to ensure we have the most up-to-date agent positions
        self.world = authoritative
        
        // CRITICAL FIX #3: We're directly using the server's world,
        // so we don't need to update the server's world reference again
        // DO NOT call updateWorld here to avoid circular references
        
        // Now check our local world state to verify it matches
        logger.info("🌍 After sync - Agent positions in WorldScene:")
        for (agentId, agent) in self.world.agents {
            logger.info("Agent \(agentId) at (\(agent.position.x), \(agent.position.y))")
        }
        
        // Use debug dumps to validate the self.world structure
        validateAgentPositions()
        
        // Send observations and update renderer
        sendObservationsAndUpdateRenderer(nextTimeStep: nextTimeStep)
    }
    
    // Helper method to validate agent positions
    private func validateAgentPositions() {
        logger.info("------ POSITIONS VALIDATION ------")
        for (agentId, agent) in self.world.agents {
            let currentTileType = self.world.tiles[agent.position.y][agent.position.x]
            logger.info("Agent \(agentId) at (\(agent.position.x), \(agent.position.y)) on \(currentTileType.description) tile")
        }
        
        // CRITICAL FIX #4: Create and validate a test observation before sending
        // to verify our agent position is correctly reflected
        if let agent = self.world.agents.first {
            let agentId = agent.key
            if let testObservation = self.world.createObservation(for: agentId, timeStep: currentTimeStep + 1) {
                logger.info("✅ Test observation for agent \(agentId): position=(\(testObservation.currentLocation.x), \(testObservation.currentLocation.y)) type=\(testObservation.currentLocation.type)")
            }
        }
    }
    
    // Helper method to send observations and update renderer
    private func sendObservationsAndUpdateRenderer(nextTimeStep: Int) {
        // Send observations using the verified synchronized world state
        logger.info("📤 SENDING OBSERVATIONS - timestep=\(nextTimeStep)")
        serverConnectionManager.sendObservationsToAll(timeStep: nextTimeStep)
        
        // Update the renderer with the current world state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update the renderer with the verified world
            self.worldRenderer.updateWorld(self.world)
            self.worldRenderer.renderWorld(in: self)
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the current time step in the world
    func getCurrentTimeStep() -> Int {
        return currentTimeStep
    }
    
    /// Regenerate the world with a new random state
    func regenerateWorld() {
        // Stop the current server first
        serverConnectionManager.stopServer()
        
        // Generate a new world
        world = World.generateWorld()
        
        // Create a new server connection manager with the new world
        serverConnectionManager = ServerConnectionManager(world: world)
        serverConnectionManager.delegate = self
        
        // Remove all children from the scene before creating a new renderer
        self.removeAllChildren()
        
        // Re-add the camera
        self.addChild(cameraNode)
        self.camera = cameraNode
        
        // Create a new WorldRenderer with a fresh cache
        worldRenderer = WorldRenderer(world: world, tileSize: tileSize)
        worldRenderer.renderWorld(in: self)
        
        // Reset time step when regenerating world
        currentTimeStep = 0
        
        // Reset camera zoom and position using smooth interpolation
        targetZoom = minZoom
        hasTargetZoom = true
        
        // Center camera on the world
        let worldWidth = CGFloat(World.size) * tileSize
        let worldHeight = CGFloat(World.size) * tileSize
        cameraTargetPosition = CGPoint(x: worldWidth / 2, y: worldHeight / 2)
        hasTargetPosition = true
        
        logger.debug("Camera reset: position=\(cameraNode.position), zoom=\(currentZoom)")
        
        // Notify that agents have changed (they've all been removed in the new world)
        NotificationCenter.default.post(name: .agentsDidChange, object: nil)
    }
}