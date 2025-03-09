//
//  WorldScene.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit
import OSLog

class WorldScene: SKScene, InputHandlerDelegate, ServerConnectionManagerDelegate {
    // Change from private to internal access level to allow synchronization
    internal var world: World!
    internal var tileSize: CGFloat = 10
    private var worldRenderer: WorldRenderer!
    private var inputHandler: InputHandler!
    private var currentTimeStep: Int = 0
    private var serverConnectionManager: ServerConnectionManager!
    
    private let logger = AppLogger(category: "WorldScene")
    
    // Camera for zooming and panning
    private var cameraNode: SKCameraNode!
    
    // Old tracking variables (no longer used)
    private var oldTargetCameraPosition: CGPoint = .zero
    
    // Only update camera in the update method for smooth movement
    private var needsCameraUpdate = false
    
    // Camera tracking state
    private var isTrackingAgent = false
    
    // Zoom constraints
    private let minZoom: CGFloat = 1.0  // Default zoom (whole map visible)
    private let maxZoom: CGFloat = 5.0  // Maximum zoom level
    private var currentZoom: CGFloat = 1.0
    
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
        
        // Setup camera for zooming and panning
        setupCamera()
        
        // Render the world
        worldRenderer.renderWorld(in: self)
    }
    
    private func setupCamera() {
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
    
    func setWorld(_ newWorld: World) {
        world = newWorld
    }
    
    // MARK: - Input Handling
    
    // Target-based camera system with smooth interpolation for both panning and zooming
    private var isDragging = false
    private var lastUpdateTime: TimeInterval = 0
    private var hasTargetPosition = false
    private var cameraTargetPosition = CGPoint.zero
    
    // Zoom interpolation
    private var targetZoom: CGFloat = 1.0
    private var hasTargetZoom = false
    
    override func update(_ currentTime: TimeInterval) {
        // Game loop updates would go here
        
        // Handle camera position updates in the main update loop for smoother movement
        if hasTargetPosition && cameraNode.position != cameraTargetPosition {
            // Calculate a smooth interpolation to the target position
            let positionSmoothFactor: CGFloat = 0.5 // Higher = faster movement
            let dx = cameraTargetPosition.x - cameraNode.position.x
            let dy = cameraTargetPosition.y - cameraNode.position.y
            
            // Move camera towards target using interpolation
            // This smooths out the movement significantly
            cameraNode.position = CGPoint(
                x: cameraNode.position.x + dx * positionSmoothFactor,
                y: cameraNode.position.y + dy * positionSmoothFactor
            )
            
            // If we're very close to the target, snap to exact position
            // This ensures we don't miss the target due to diminishing changes
            if abs(dx) < 1.0 && abs(dy) < 1.0 {
                cameraNode.position = cameraTargetPosition
                // Once we've reached the target, stop tracking it
                if !isTrackingAgent {
                    hasTargetPosition = false
                }
            }
        }
        
        // Handle zoom interpolation in the update loop
        if hasTargetZoom && abs(currentZoom - targetZoom) > 0.001 {
            // Calculate a smooth interpolation to the target zoom
            let zoomSmoothFactor: CGFloat = 0.6 // Increased from 0.3 for faster zooming
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
            }
        }
        
        // Update timing for next frame
        lastUpdateTime = currentTime
    }
    
    override func mouseDown(with event: NSEvent) {
        // Start panning
        isDragging = true
        
        // Initialize at current position (no movement yet)
        cameraTargetPosition = cameraNode.position
        hasTargetPosition = true
        
        // Only pass to input handler for actual clicks
        if event.clickCount > 0 {
            inputHandler.handleMouseDown(with: event, in: self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        // Skip if we're not in dragging mode
        guard isDragging else { return }
        
        // Disable agent tracking when manually dragging
        isTrackingAgent = false
        
        // Filter out tiny movements that can cause jitter
        let dx = event.deltaX
        let dy = event.deltaY
        
        // Apply sensitivity - higher = faster panning
        let sensitivity: CGFloat = 2.0
        
        // Calculate new target position based on current target (not current camera position)
        let newTargetX = cameraTargetPosition.x - dx * sensitivity / currentZoom
        let newTargetY = cameraTargetPosition.y + dy * sensitivity / currentZoom
        
        // Update target position with constraints
        cameraTargetPosition = constrainPositionToBounds(CGPoint(x: newTargetX, y: newTargetY))
    }
    
    override func mouseUp(with event: NSEvent) {
        // End dragging mode
        isDragging = false
        
        // If user was dragging, disable agent tracking
        if event.deltaX != 0 || event.deltaY != 0 {
            isTrackingAgent = false
        }
        
        // Stop targeting after a short delay to allow smooth finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.hasTargetPosition = false
        }
    }
    
    // Constrain position without changing it (pure function)
    private func constrainPositionToBounds(_ position: CGPoint) -> CGPoint {
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
    
    // Public method that can be called directly from our custom view
    func handleScrollWheel(with event: NSEvent) {
        logger.debug("Direct scroll wheel handling with scrollingDeltaY: \(event.scrollingDeltaY)")
        
        // Only process if there's actual scroll delta
        if abs(event.scrollingDeltaY) > 0.1 {
            // Reversed direction - now scrolling up (negative scrollingDeltaY) means zoom out
            let zoomDirection: CGFloat = event.scrollingDeltaY > 0 ? 1 : -1
            
            // Significantly faster zoom amount for scroll wheel
            let zoomAmount: CGFloat = 0.3 * zoomDirection
            
            // Get mouse location in scene coordinates to zoom toward that point
            let mouseLocation = event.location(in: self)
            
            // Apply smoother zooming with larger increments
            smoothZoom(by: zoomAmount, towardPoint: mouseLocation)
        }
    }
    
    // Add keyboard control for zooming as an alternative method
    override func keyDown(with event: NSEvent) {
        // Get the pressed key
        if let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "=", "+": // Zoom in with plus key
                // For keyboard zoom, use center of screen
                let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
                smoothZoom(by: 1.0, towardPoint: centerPoint)
            case "-", "_": // Zoom out with minus key
                let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
                smoothZoom(by: -1.0, towardPoint: centerPoint)
            case "0":      // Reset zoom
                resetZoom()
            default:
                // Pass other keys to default handler
                super.keyDown(with: event)
            }
        }
    }
    
    // New smooth zoom method that uses interpolation
    private func smoothZoom(by amount: CGFloat, towardPoint: CGPoint? = nil) {
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
    
    // Legacy zoom method (kept for reference, not used anymore)
    private func changeZoom(by amount: CGFloat, towardPoint: CGPoint? = nil) {
        // This has been replaced by smoothZoom
        smoothZoom(by: amount, towardPoint: towardPoint)
    }
    
    private func resetZoom() {
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
    
    // Note: This is now replaced by constrainPositionToBounds which doesn't modify the camera
    private func moveCameraWithinBounds(to position: CGPoint) {
        cameraNode.position = constrainPositionToBounds(position)
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
        
        // Send updated observations to all connected agents only during timestep updates
        serverConnectionManager.sendObservationsToAll(timeStep: nextTimeStep)
        
        // Log the simulation step
        logger.info("Simulating time step: \(nextTimeStep)")
        
        // Update the UI with new agent positions
        DispatchQueue.main.async {
            // Use worldDidUpdate which preserves the existing renderer and its texture caches
            self.worldDidUpdate(self.world)
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the current time step in the world
    func getCurrentTimeStep() -> Int {
        return currentTimeStep
    }
    
    /// Focus the camera on a specific agent
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
    
    // MARK: - ServerConnectionManagerDelegate
    
    func worldDidUpdate(_ updatedWorld: World) {
        // The world has been updated, so update the renderer and redraw
        self.world = updatedWorld
        
        // Update the world reference in the renderer without recreating it
        DispatchQueue.main.async {
            // Update the world reference in the renderer
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
        
        // Create a new WorldRenderer to ensure it has fresh data
        DispatchQueue.main.async {
            // Explicitly recreate the renderer to ensure it sees the updated world
            self.worldRenderer = WorldRenderer(world: self.world, tileSize: self.tileSize)
            self.worldRenderer.renderWorld(in: self)
            
            // Debug - log all agents in the world after rendering
            for (agentId, agent) in self.world.agents {
                self.logger.info("After render: Agent \(agentId) in world at position (\(agent.position.x), \(agent.position.y))")
            }
            
            // More aggressive notification - set this as the notification object so observers can access it
            self.logger.debug("🔔 Publishing agentsDidChange notification")
            NotificationCenter.default.post(name: .agentsDidChange, object: self.world)
        }
    }
    
    func agentDidDisconnect(id: String) {
        logger.info("Agent disconnected: \(id)")
        
        // Re-render to remove the agent
        DispatchQueue.main.async {
            // Explicitly recreate the renderer to ensure it has the most up-to-date world state
            self.worldRenderer = WorldRenderer(world: self.world, tileSize: self.tileSize)
            self.worldRenderer.renderWorld(in: self)
            
            // Log confirmation of agent removal
            if self.world.agents[id] == nil {
                self.logger.info("Agent \(id) successfully removed from world")
            } else {
                self.logger.error("Agent \(id) still present in world after disconnect!")
            }
            
            // More aggressive notification with world object
            self.logger.debug("🔔 Publishing agentsDidChange notification for disconnect")
            NotificationCenter.default.post(name: .agentsDidChange, object: self.world)
        }
    }
    
    func serverDidEncounterError(_ error: Error) {
        logger.error("Server error: \(error.localizedDescription)")
    }
}
