//
//  WorldScene+ServerDelegate.swift
//  AgentWorld
//
//  Created by Claude on 3/9/25.
//

import SpriteKit

// Extension to handle server delegate functionality
extension WorldScene {
    // MARK: - ServerConnectionManagerDelegate
    
    func worldDidUpdate(_ updatedWorld: World) {
        // Log agent positions in the updated world for debugging (safely)
        logger.info("🔄 worldDidUpdate called - Agents in updated world:")
        
        // CRITICAL FIX: Prevent crash when updatedWorld.agents is nil or empty
        if !updatedWorld.agents.isEmpty {
            let agentCount = updatedWorld.agents.count
            logger.info("Found \(agentCount) agents in updated world")
            
            // Use safe iteration in case the collection changes
            let agents = updatedWorld.agents // Create a local copy
            for (agentId, agent) in agents {
                // Use direct string interpolation to avoid potential formatter issues
                logger.info("Agent \(agentId) at position: \(agent.position.x), \(agent.position.y)")
            }
        } else {
            logger.info("No agents in updated world")
        }
        
        // Update our local world reference - always on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update our local world reference
            self.world = updatedWorld
            
            // DO NOT update ServerConnectionManager's world here to avoid circular updates
            // The ServerConnectionManager already has this world reference
            
            // Update the world reference in the renderer without recreating it
            self.worldRenderer.updateWorld(self.world)
            
            // Then render the world (this will only update agents, not tiles)
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
        
        updateWorldAndNotify()
    }
    
    func agentDidDisconnect(id: String) {
        logger.info("Agent disconnected: \(id)")
        
        // Force the world renderer to remove any tile/sprite associated with this agent
        if let node = worldRenderer.getAgentNode(for: id) {
            node.removeFromParent()
            node.removeAllActions()
            logger.info("Removed agent node for \(id) from scene")
        }
        
        // Update the world and notify listeners
        updateWorldAndNotify(agentId: id, isDisconnect: true)
    }
    
    func serverDidEncounterError(_ error: Error) {
        logger.error("Server error: \(error.localizedDescription)")
    }
    
    // MARK: - WorldSceneDelegate
    
    func agentDidMove(id: String, to position: (x: Int, y: Int)) {
        logger.info("🔄 agentDidMove called - Agent \(id) moved to (\(position.x), \(position.y))")
        
        // IMPORTANT: We don't need to update world reference here, as it was already updated
        // in the AgentMessageHandler. Just update the renderer.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update the renderer without recreating it
            self.worldRenderer.updateWorld(self.world)
            self.worldRenderer.renderWorld(in: self)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateWorldAndNotify(agentId: String? = nil, isDisconnect: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Explicitly recreate the renderer to ensure it has the most up-to-date world state
            self.worldRenderer = WorldRenderer(world: self.world, tileSize: self.tileSize)
            self.worldRenderer.renderWorld(in: self)
            
            // Log confirmation if disconnecting an agent
            if let id = agentId, isDisconnect {
                if self.world.agents[id] == nil {
                    self.logger.info("Agent \(id) successfully removed from world")
                } else {
                    self.logger.error("Agent \(id) still present in world after disconnect!")
                }
            } else {
                // Debug - log all agents in the world after rendering
                for (agentId, agent) in self.world.agents {
                    self.logger.info("After render: Agent \(agentId) in world at position (\(agent.position.x), \(agent.position.y))")
                }
            }
            
            // More aggressive notification with world object
            self.logger.debug("🔔 Publishing agentsDidChange notification")
            NotificationCenter.default.post(name: .agentsDidChange, object: self.world)
        }
    }
}