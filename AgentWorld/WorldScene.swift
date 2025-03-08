//
//  WorldScene.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit

class WorldScene: SKScene, InputHandlerDelegate {
    private var world: World!
    private var tileSize: CGFloat = 10
    private var worldRenderer: WorldRenderer!
    private var inputHandler: InputHandler!
    private var currentTimeStep: Int = 0
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .black
        
        // Generate a new world
        world = World.generateWorld()
        
        // Calculate tile size based on the view size
        let smallerDimension = min(size.width, size.height)
        tileSize = smallerDimension / CGFloat(World.size)
        
        // Initialize components
        worldRenderer = WorldRenderer(world: world, tileSize: tileSize)
        inputHandler = InputHandler(delegate: self)
        
        // Render the world
        worldRenderer.renderWorld(in: self)
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
        // This is where you would implement simulation logic for the world
        // For example:
        // - Update agent positions
        // - Grow or deplete resources
        // - Handle agent interactions
        // - Apply environmental effects
        
        // For now, we'll just have a placeholder
        print("Simulating time step: \(currentTimeStep + 1)")
    }
    
    // MARK: - Public Methods
    
    func regenerateWorld() {
        world = World.generateWorld()
        
        // Create a new WorldRenderer with a fresh cache
        worldRenderer = WorldRenderer(world: world, tileSize: tileSize)
        worldRenderer.renderWorld(in: self)
        
        // Reset time step when regenerating world
        currentTimeStep = 0
    }
}