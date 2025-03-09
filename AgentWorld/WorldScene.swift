//
//  WorldScene.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit
import OSLog

// Define a new protocol for more specific WorldScene updates
protocol WorldSceneDelegate: ServerConnectionManagerDelegate {
    func agentDidMove(id: String, to position: (x: Int, y: Int))
}

// Main WorldScene class with core properties and methods
class WorldScene: SKScene, InputHandlerDelegate, WorldSceneDelegate {
    // MARK: - Core Properties
    
    internal var world: World!
    internal var tileSize: CGFloat = 10
    internal var worldRenderer: WorldRenderer!
    internal var inputHandler: InputHandler!
    internal var serverConnectionManager: ServerConnectionManager!
    
    // Shared logger used across all extensions
    let logger = AppLogger(category: "WorldScene")
    
    // MARK: - Camera Properties
    
    internal var cameraNode: SKCameraNode!
    internal var isTrackingAgent = false
    internal var minZoom: CGFloat = 1.0
    internal var maxZoom: CGFloat = 5.0
    internal var currentZoom: CGFloat = 1.0
    internal var targetZoom: CGFloat = 1.0
    internal var hasTargetZoom = false
    internal var cameraTargetPosition = CGPoint.zero
    internal var hasTargetPosition = false
    internal var lastCameraUpdateTime: TimeInterval = 0
    internal var cameraUpdateInterval: TimeInterval = 1.0 / 60.0 // 60 fps target
    
    // MARK: - Input Properties
    
    internal var isDragging = false
    internal var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Simulation Properties
    
    internal var currentTimeStep: Int = 0
    
    // MARK: - Initialization
    
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
    
    // MARK: - Core Update Method
    
    override func update(_ currentTime: TimeInterval) {
        // Only update camera at a fixed rate to reduce CPU usage
        let timeSinceLastUpdate = currentTime - lastCameraUpdateTime
        if timeSinceLastUpdate >= cameraUpdateInterval {
            updateCamera()
            lastCameraUpdateTime = currentTime
        }
        
        // Update timing for next frame
        lastUpdateTime = currentTime
    }
    
    // MARK: - World Management
    
    func setWorld(_ newWorld: World) {
        world = newWorld
    }
    
    // MARK: - InputHandlerDelegate
    
    func inputHandler(_ handler: InputHandler, didClickAtPosition position: CGPoint) {
        // Handle click events from input handler
        // This could be expanded for handling different types of interactions
    }
}
