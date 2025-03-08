//
//  WorldRenderer.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit

class WorldRenderer {
    private let world: World
    private let tileSize: CGFloat
    private let tileRenderer: TileRenderer
    
    // Cache for tile nodes to prevent regeneration
    private var tileNodeCache: [[SKSpriteNode?]] = Array(repeating: Array(repeating: nil, count: World.size), count: World.size)
    
    // Cache for agent nodes
    private var agentNodeCache: [String: SKSpriteNode] = [:]
    
    init(world: World, tileSize: CGFloat) {
        self.world = world
        self.tileSize = tileSize
        self.tileRenderer = TileRenderer(tileSize: tileSize)
        clearTileCache()
    }
    
    /// Clears the tile node cache
    public func clearTileCache() {
        tileNodeCache = Array(repeating: Array(repeating: nil, count: World.size), count: World.size)
        agentNodeCache = [:]
    }
    
    func renderWorld(in scene: SKScene) {
        // Remove existing tiles if any
        scene.removeAllChildren()
        
        // Create and place tile sprites
        for y in 0..<World.size {
            for x in 0..<World.size {
                let tileType = world.tiles[y][x]
                
                // Get cached node or create a new one if it doesn't exist
                let tileNode: SKSpriteNode
                if let cachedNode = tileNodeCache[y][x] {
                    tileNode = cachedNode
                } else {
                    tileNode = tileRenderer.createTileNode(for: tileType, size: CGSize(width: tileSize, height: tileSize))
                    tileNodeCache[y][x] = tileNode
                }
                
                // Position in the scene (convert from grid to screen coordinates)
                tileNode.position = CGPoint(
                    x: CGFloat(x) * tileSize + tileSize/2,
                    y: scene.size.height - (CGFloat(y) * tileSize + tileSize/2) // Flip Y-axis
                )
                
                // Set zPosition to ensure tiles are at the bottom
                tileNode.zPosition = 0
                
                // Add to scene
                scene.addChild(tileNode)
            }
        }
        
        // Render agents
        renderAgents(in: scene)
    }
    
    private func renderAgents(in scene: SKScene) {
        // First, log debug info about all agents being rendered
        print("🤖 Rendering \(world.agents.count) agents in the world")
        
        // Render all agents in the world
        for (agentID, agentInfo) in world.agents {
            print("🤖 Rendering agent \(agentID) at position (\(agentInfo.position.x), \(agentInfo.position.y))")
            // Get cached node or create a new one
            let agentNode: SKSpriteNode
            if let cachedNode = agentNodeCache[agentID] {
                agentNode = cachedNode
            } else {
                agentNode = tileRenderer.createAgentNode(
                    withColor: agentInfo.color,
                    size: CGSize(width: tileSize, height: tileSize)
                )
                agentNodeCache[agentID] = agentNode
            }
            
            // Position the agent
            let pos = agentInfo.position
            agentNode.position = CGPoint(
                x: CGFloat(pos.x) * tileSize + tileSize/2,
                y: scene.size.height - (CGFloat(pos.y) * tileSize + tileSize/2) // Flip Y-axis
            )
            
            // Set zPosition to ensure agents are above tiles
            agentNode.zPosition = 10
            
            // Add name for identification
            agentNode.name = "agent-\(agentID)"
            
            // Update the label with the correct agent ID
            if let label = agentNode.childNode(withName: "//SKLabelNode") as? SKLabelNode {
                label.text = String(agentID.prefix(8))
            }
            
            // Make sure the agent is visible even if it's at the edge of the screen
            agentNode.setScale(1.0) // Reset scale in case it was animated
            
            // Add to scene with a brief attention-getting animation
            scene.addChild(agentNode)
            
            // Add a brief highlight animation when first added
            let highlightAction = SKAction.sequence([
                SKAction.scale(to: 1.5, duration: 0.2),
                SKAction.scale(to: 1.0, duration: 0.2)
            ])
            agentNode.run(highlightAction)
        }
    }
}