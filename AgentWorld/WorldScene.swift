//
//  WorldScene.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit

class WorldScene: SKScene {
    private var world: World!
    private var tileSize: CGFloat = 10
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .black
        
        // Generate a new world
        world = World.generateWorld()
        
        // Calculate tile size based on the view size
        let smallerDimension = min(size.width, size.height)
        tileSize = smallerDimension / CGFloat(World.size)
        
        renderWorld()
    }
    
    private func renderWorld() {
        // Remove existing tiles if any
        self.removeAllChildren()
        
        // Create and place tile sprites
        for y in 0..<World.size {
            for x in 0..<World.size {
                let tileType = world.tiles[y][x]
                let tileNode = SKSpriteNode(color: tileType.color, size: CGSize(width: tileSize, height: tileSize))
                
                // Position in the scene (convert from grid to screen coordinates)
                tileNode.position = CGPoint(
                    x: CGFloat(x) * tileSize + tileSize/2,
                    y: size.height - (CGFloat(y) * tileSize + tileSize/2) // Flip Y-axis
                )
                
                // Add to scene
                addChild(tileNode)
            }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Game loop updates would go here
    }
    
    // MARK: - Input Handling
    
    override func mouseDown(with event: NSEvent) {
        // Handle mouse clicks
        let location = event.location(in: self)
        print("Click at \(location)")
    }
    
    func regenerateWorld() {
        world = World.generateWorld()
        renderWorld()
    }
}