//
//  WorldRenderer.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit

class WorldRenderer {
    // Changed from let to var to allow for updates
    private var world: World
    private let tileSize: CGFloat
    private let tileRenderer: TileRenderer
    // Flag to track if tiles have been rendered already
    private var tilesRendered = false
    
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
        
        // Reset container nodes
        tileContainer = nil
        agentContainer = nil
        
        // Reset the tiles rendered flag
        tilesRendered = false
    }
    
    /// Updates the world reference without recreating the renderer
    public func updateWorld(_ newWorld: World) {
        self.world = newWorld
    }
    
    // Container nodes to organize the scene
    private var tileContainer: SKNode?
    private var agentContainer: SKNode?
    
    func renderWorld(in scene: SKScene) {
        // Only initialize containers once
        if tileContainer == nil {
            tileContainer = SKNode()
            tileContainer?.name = "tileContainer"
            tileContainer?.zPosition = 0
            scene.addChild(tileContainer!)
        }
        
        if agentContainer == nil {
            agentContainer = SKNode()
            agentContainer?.name = "agentContainer"
            agentContainer?.zPosition = 10
            scene.addChild(agentContainer!)
        }
        
        // Clear only the agent container since agents can move
        agentContainer?.removeAllChildren()
        
        // Only render tiles if we haven't rendered them before
        if !tilesRendered {
            renderTiles(in: scene)
            tilesRendered = true
        }
        
        // Always render agents (they can move)
        renderAgents(in: scene)
    }
    
    private func renderTiles(in scene: SKScene) {
        guard let tileContainer = tileContainer else { return }
        
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
                
                // Name the node for identification
                tileNode.name = "tile-\(x)-\(y)"
                
                // Add to the tile container
                tileContainer.addChild(tileNode)
            }
        }
    }
    
    private func renderAgents(in scene: SKScene) {
        guard let agentContainer = agentContainer else { return }
        
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
            let newPosition = CGPoint(
                x: CGFloat(pos.x) * tileSize + tileSize/2,
                y: scene.size.height - (CGFloat(pos.y) * tileSize + tileSize/2) // Flip Y-axis
            )
            
            // Check if this is an existing agent that moved
            let isExistingAgent = agentNodeCache[agentID] == agentNode
            
            // If the agent existed before and changed position, animate the movement
            if isExistingAgent && agentNode.position != newPosition {
                // Create a smooth move action for agent movement
                let moveAction = SKAction.move(to: newPosition, duration: 0.3)
                moveAction.timingMode = .easeInEaseOut
                agentNode.run(moveAction)
            } else {
                // Otherwise just set position directly
                agentNode.position = newPosition
            }
            
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
            
            // Add to the agent container
            agentContainer.addChild(agentNode)
            
            // Add a brief highlight animation when first added
            let highlightAction = SKAction.sequence([
                SKAction.scale(to: 1.5, duration: 0.2),
                SKAction.scale(to: 1.0, duration: 0.2)
            ])
            agentNode.run(highlightAction)
        }
    }
}