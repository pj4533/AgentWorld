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
    
    // Camera for zooming and panning
    private var cameraNode: SKCameraNode!
    
    // For tracking camera position directly
    private var targetCameraPosition: CGPoint = .zero
    
    // Only update camera in the update method for smooth movement
    private var needsCameraUpdate = false
    
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
        
        // Make sure scale is properly initialized
        cameraNode.setScale(1.0 / currentZoom)
        
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
    
    override func update(_ currentTime: TimeInterval) {
        // Game loop updates would go here
    }
    
    // MARK: - Input Handling
    
    // Track panning with absolute positions
    private var panningStartPoint: CGPoint?
    private var cameraStartPosition: CGPoint?
    
    override func mouseDown(with event: NSEvent) {
        // Record starting points for panning
        panningStartPoint = event.location(in: self)
        cameraStartPosition = cameraNode.position
        
        // Only pass to input handler for actual clicks, not panning
        if event.clickCount > 0 {
            inputHandler.handleMouseDown(with: event, in: self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let startPoint = panningStartPoint,
              let startCamera = cameraStartPosition else { return }
        
        // Get current location in the view's coordinate space
        let currentPoint = event.location(in: self)
        
        // Calculate delta
        let dx = currentPoint.x - startPoint.x
        let dy = currentPoint.y - startPoint.y
        
        // Apply panning sensitivity
        let panSensitivity: CGFloat = 3.0
        
        // Set new position directly
        let newX = startCamera.x - (dx * panSensitivity) / currentZoom
        let newY = startCamera.y - (dy * panSensitivity) / currentZoom
        
        // Update camera position directly (no interim step)
        let constrainedPosition = constrainPositionToBounds(CGPoint(x: newX, y: newY))
        cameraNode.position = constrainedPosition
    }
    
    override func mouseUp(with event: NSEvent) {
        panningStartPoint = nil
        cameraStartPosition = nil
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
        
        // Handle smooth scrolling properly
        let zoomAmount: CGFloat = 0.05
        
        // Only process if there's actual scroll delta
        if abs(event.scrollingDeltaY) > 0.1 {
            // Reversed direction - now scrolling up (negative scrollingDeltaY) means zoom out
            let zoomDirection: CGFloat = event.scrollingDeltaY > 0 ? 1 : -1
            
            // Get mouse location in scene coordinates to zoom toward that point
            let mouseLocation = event.location(in: self)
            
            changeZoom(by: zoomDirection * zoomAmount, towardPoint: mouseLocation)
        }
    }
    
    // We don't need to override scrollWheel since we're handling it in ZoomableSkView
    // This prevents duplicate processing which was causing the strange zoom behavior
    /*
    override func scrollWheel(with event: NSEvent) {
        // The standard event handler - log info but forward to our custom handler
        logger.debug("Scene scrollWheel received: deltaY=\(event.deltaY)")
        
        // Use our dedicated handler
        handleScrollWheel(with: event)
    }
    */
    
    // Add keyboard control for zooming as an alternative method
    override func keyDown(with event: NSEvent) {
        // Get the pressed key
        if let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "=", "+": // Zoom in with plus key
                // For keyboard zoom, use center of screen
                let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
                changeZoom(by: 0.2, towardPoint: centerPoint)
            case "-", "_": // Zoom out with minus key
                let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
                changeZoom(by: -0.2, towardPoint: centerPoint)
            case "0":      // Reset zoom
                resetZoom()
            default:
                // Pass other keys to default handler
                super.keyDown(with: event)
            }
        }
    }
    
    private func changeZoom(by amount: CGFloat, towardPoint: CGPoint? = nil) {
        var newZoom = currentZoom + amount
        
        // Constrain zoom within min/max limits
        newZoom = max(minZoom, min(maxZoom, newZoom))
        
        if newZoom != currentZoom {
            // If a specific point is provided, zoom toward that point
            var newCameraPosition = cameraNode.position
            
            if let zoomPoint = towardPoint {
                // Calculate vector from zoom point to camera
                let vectorX = cameraNode.position.x - zoomPoint.x
                let vectorY = cameraNode.position.y - zoomPoint.y
                
                // Scale factor based on how much we're zooming
                let zoomFactor = 1.0 - (newZoom / currentZoom)
                
                // Move camera based on zoom point direction and zoom amount
                newCameraPosition = CGPoint(
                    x: cameraNode.position.x + (vectorX * zoomFactor),
                    y: cameraNode.position.y + (vectorY * zoomFactor)
                )
            }
            
            logger.debug("Zoom changing: \(currentZoom) to \(newZoom)")
            
            // Apply zoom directly
            cameraNode.setScale(1.0 / newZoom)
            currentZoom = newZoom
            
            // After zooming, ensure camera remains within bounds
            moveCameraWithinBounds(to: newCameraPosition)
        }
    }
    
    private func resetZoom() {
        currentZoom = minZoom
        cameraNode.setScale(1.0 / minZoom)
        
        // Center camera
        let worldWidth = CGFloat(World.size) * tileSize
        let worldHeight = CGFloat(World.size) * tileSize
        cameraNode.position = CGPoint(x: worldWidth / 2, y: worldHeight / 2)
        
        logger.debug("Zoom reset to \(currentZoom)")
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
        
        // Reset camera zoom and position
        currentZoom = minZoom
        cameraNode.setScale(1.0 / minZoom)
        
        // Center camera on the world
        let worldWidth = CGFloat(World.size) * tileSize
        let worldHeight = CGFloat(World.size) * tileSize
        cameraNode.position = CGPoint(x: worldWidth / 2, y: worldHeight / 2)
        
        logger.debug("Camera reset: position=\(cameraNode.position), zoom=\(currentZoom)")
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
            // Explicitly recreate the renderer to ensure it has the most up-to-date world state
            self.worldRenderer = WorldRenderer(world: self.world, tileSize: self.tileSize)
            self.worldRenderer.renderWorld(in: self)
            
            // Log confirmation of agent removal
            if self.world.agents[id] == nil {
                self.logger.info("Agent \(id) successfully removed from world")
            } else {
                self.logger.error("Agent \(id) still present in world after disconnect!")
            }
        }
    }
    
    func serverDidEncounterError(_ error: Error) {
        logger.error("Server error: \(error.localizedDescription)")
    }
}
