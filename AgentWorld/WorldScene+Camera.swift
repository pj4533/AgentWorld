//
//  WorldScene+Camera.swift
//  AgentWorld
//
//  Created by Claude on 3/9/25.
//

import SpriteKit

// Extension to handle camera-related functionality
extension WorldScene {
    // MARK: - Camera Setup
    
    func setupCamera() {
        cameraNode = SKCameraNode()
        
        // Position camera at center of the world
        let worldWidth = CGFloat(World.size) * tileSize
        let worldHeight = CGFloat(World.size) * tileSize
        cameraNode.position = CGPoint(x: worldWidth / 2, y: worldHeight / 2)
        
        // Initialize camera zoom
        cameraNode.setScale(1.0 / currentZoom)
        
        // Initialize target values for smooth interpolation
        targetZoom = currentZoom
        cameraTargetPosition = cameraNode.position
        
        // Add the camera to the scene
        self.addChild(cameraNode)
        self.camera = cameraNode
        
        // Enable user interaction for panning and zooming
        self.isUserInteractionEnabled = true
        
        logger.debug("Camera initialized: position=\(cameraNode.position), zoom=\(currentZoom)")
    }
    
    // MARK: - Camera Updates
    
    func updateCamera() {
        // Early return if no camera updates are needed
        if !hasTargetPosition && !hasTargetZoom {
            return
        }
        
        updateCameraPosition()
        updateCameraZoom()
    }
    
    private func updateCameraPosition() {
        // Handle camera position updates
        if hasTargetPosition && cameraNode.position != cameraTargetPosition {
            // Calculate a smooth interpolation to the target position
            let positionSmoothFactor: CGFloat = 0.5 // Higher = faster movement
            let dx = cameraTargetPosition.x - cameraNode.position.x
            let dy = cameraTargetPosition.y - cameraNode.position.y
            
            // Only update if the change is significant enough to be visible
            if abs(dx) > 0.1 || abs(dy) > 0.1 {
                // Move camera towards target using interpolation
                cameraNode.position = CGPoint(
                    x: cameraNode.position.x + dx * positionSmoothFactor,
                    y: cameraNode.position.y + dy * positionSmoothFactor
                )
            } else {
                // Snap to position if we're very close
                cameraNode.position = cameraTargetPosition
                // Once we've reached the target, stop tracking it
                if !isTrackingAgent {
                    hasTargetPosition = false
                }
            }
        }
    }
    
    private func updateCameraZoom() {
        // Handle zoom interpolation
        if hasTargetZoom && abs(currentZoom - targetZoom) > 0.001 {
            // Calculate a smooth interpolation to the target zoom
            let zoomSmoothFactor: CGFloat = 0.6
            let dZoom = targetZoom - currentZoom
            
            // Update the current zoom with smoothing
            let newZoom = currentZoom + dZoom * zoomSmoothFactor
            
            // Apply the new zoom
            cameraNode.setScale(1.0 / newZoom)
            currentZoom = newZoom
            
            // If we're very close to the target, just set it exactly
            if abs(currentZoom - targetZoom) < 0.01 {
                currentZoom = targetZoom
                cameraNode.setScale(1.0 / currentZoom)
                hasTargetZoom = false
                
                // Force re-render after zoom changes to update node detail levels
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.worldRenderer.renderWorld(in: self)
                }
            }
        }
    }
    
    // MARK: - Camera Constraints
    
    func constrainPositionToBounds(_ position: CGPoint) -> CGPoint {
        // Calculate world dimensions
        let worldWidth = CGFloat(World.size) * tileSize
        let worldHeight = CGFloat(World.size) * tileSize
        
        // Calculate visible area based on current zoom
        let visibleWidth = size.width / currentZoom
        let visibleHeight = size.height / currentZoom
        
        // Calculate bounds
        let minX = visibleWidth / 2
        let maxX = worldWidth - visibleWidth / 2
        let minY = visibleHeight / 2
        let maxY = worldHeight - visibleHeight / 2
        
        // Constrain X position
        var newX = position.x
        if minX < maxX {
            newX = max(minX, min(maxX, newX))
        } else {
            newX = worldWidth / 2
        }
        
        // Constrain Y position
        var newY = position.y
        if minY < maxY {
            newY = max(minY, min(maxY, newY))
        } else {
            newY = worldHeight / 2
        }
        
        return CGPoint(x: newX, y: newY)
    }
    
    // MARK: - Zoom Control
    
    func smoothZoom(by amount: CGFloat, towardPoint: CGPoint? = nil) {
        // Calculate new target zoom level
        let newTargetZoom = max(minZoom, min(maxZoom, currentZoom + amount))
        
        // Only proceed if we're actually changing zoom
        if newTargetZoom != targetZoom {
            // Disable agent tracking when user manually zooms
            isTrackingAgent = false
            
            targetZoom = newTargetZoom
            hasTargetZoom = true
            
            // If we're zooming toward a specific point, update camera target position
            if let zoomPoint = towardPoint {
                // Calculate vector from zoom point to camera
                let vectorX = cameraNode.position.x - zoomPoint.x
                let vectorY = cameraNode.position.y - zoomPoint.y
                
                // Scale factor based on how much we're zooming
                let zoomFactor = 1.0 - (targetZoom / currentZoom)
                
                // Update the target camera position 
                cameraTargetPosition = CGPoint(
                    x: cameraNode.position.x + (vectorX * zoomFactor),
                    y: cameraNode.position.y + (vectorY * zoomFactor)
                )
                
                // Constrain the target position
                cameraTargetPosition = constrainPositionToBounds(cameraTargetPosition)
                hasTargetPosition = true
            }
            
            logger.debug("Zoom target set: \(currentZoom) → \(targetZoom)")
        }
    }
    
    func resetZoom() {
        // Set target zoom to minimum (default) zoom
        targetZoom = minZoom
        hasTargetZoom = true
        
        // Set target position to center of world
        let worldWidth = CGFloat(World.size) * tileSize
        let worldHeight = CGFloat(World.size) * tileSize
        cameraTargetPosition = CGPoint(x: worldWidth / 2, y: worldHeight / 2)
        hasTargetPosition = true
        
        logger.debug("Zoom and position reset initiated")
    }
    
    // MARK: - Agent Focusing
    
    func focusOnAgent(id: String) {
        // Get the agent info
        guard let agent = world.agents[id] else {
            logger.error("Cannot focus on agent \(id): agent not found")
            return
        }
        
        // Enable agent tracking mode
        isTrackingAgent = true
        
        // Use a higher zoom level for better visibility
        targetZoom = 3.0
        hasTargetZoom = true
        
        // Calculate world position for this agent - center precisely
        // CRITICAL: Must flip Y-axis to match how WorldRenderer positions agents
        let worldX = CGFloat(agent.position.x) * tileSize + (tileSize / 2)
        let worldY = self.size.height - (CGFloat(agent.position.y) * tileSize + (tileSize / 2))
        
        // Force immediate position update to center exactly on the agent
        cameraTargetPosition = CGPoint(x: worldX, y: worldY)
        hasTargetPosition = true
        
        // First, cancel any existing camera constraints to ensure our new target is prioritized
        self.cameraNode.constraints = nil
        
        // Set position directly first for immediate effect
        cameraNode.position = CGPoint(x: worldX, y: worldY)
        
        // Then apply a finishing movement with smooth easing
        let moveAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.01), // Tiny delay to ensure direct position is applied first
            SKAction.move(to: CGPoint(x: worldX, y: worldY), duration: 0.3)
        ])
        moveAction.timingMode = .easeOut
        cameraNode.run(moveAction)
        
        // Log that we're setting camera position
        logger.info("Setting camera to position: (\(worldX), \(worldY))")
        
        // Make another target update after a short delay to ensure centering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.world.agents[id] != nil else { return }
            
            // Second precise position update
            self.cameraTargetPosition = CGPoint(x: worldX, y: worldY)
            self.hasTargetPosition = true
            
            // After the camera has moved (with some delay), disable tracking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.isTrackingAgent = false
            }
            
            // Log detailed coordinate information for debugging
            self.logger.info("Focusing on agent \(id) at position (\(agent.position.x), \(agent.position.y))")
            self.logger.info("Scene size: \(self.size.width) x \(self.size.height)")
            self.logger.info("World coordinates (after Y-flip): (\(worldX), \(worldY))")
            self.logger.info("Camera now at position: \(self.cameraNode.position)")
        }
    }
}