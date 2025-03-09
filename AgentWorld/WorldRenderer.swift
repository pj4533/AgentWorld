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
        
        // Remove any cached agent nodes for agents that don't exist anymore
        // and cancel any running animations
        let currentAgentIds = Set(newWorld.agents.keys)
        let cachedAgentIds = Set(agentNodeCache.keys)
        
        // Remove nodes for agents that no longer exist
        for agentId in cachedAgentIds {
            if !currentAgentIds.contains(agentId) {
                if let node = agentNodeCache[agentId] {
                    // Stop all animations and remove from parent
                    node.removeAllActions()
                    node.removeFromParent()
                }
                agentNodeCache.removeValue(forKey: agentId)
            } else {
                // For existing agents, stop any running animations
                agentNodeCache[agentId]?.removeAllActions()
            }
        }
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
        
        // First, search for any stray agent nodes that might exist elsewhere in the scene
        // (sometimes SpriteKit nodes can end up in unexpected places)
        scene.enumerateChildNodes(withName: "agent-*") { node, _ in
            if node.parent != self.agentContainer {
                node.removeFromParent()
            }
        }
        
        // Clear all agent nodes from the scene
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
        
        // Remove all agent nodes from the scene
        scene.enumerateChildNodes(withName: "//agent-*") { node, _ in
            node.removeFromParent()
        }
        agentContainer.removeAllChildren()
        
        // Clear the cache completely to prevent any stale references
        for (_, node) in agentNodeCache {
            node.removeAllActions()
            node.removeFromParent()
        }
        agentNodeCache.removeAll()
        
        // Render all agents in the world with brand new nodes
        for (agentID, agentInfo) in world.agents {
            print("🤖 Rendering agent \(agentID) at position (\(agentInfo.position.x), \(agentInfo.position.y))")
            
            // Always create a new agent node to avoid any caching issues
            let agentNode = tileRenderer.createAgentNode(
                withColor: agentInfo.color,
                size: CGSize(width: tileSize, height: tileSize)
            )
            
            // Store in cache
            agentNodeCache[agentID] = agentNode
            
            // Position the agent at its current position
            let pos = agentInfo.position
            let newPosition = CGPoint(
                x: CGFloat(pos.x) * tileSize + tileSize/2,
                y: scene.size.height - (CGFloat(pos.y) * tileSize + tileSize/2) // Flip Y-axis
            )
            
            // Set position directly
            agentNode.position = newPosition
            
            // Set zPosition to ensure agents are above tiles
            agentNode.zPosition = 10
            
            // Add name for identification including position to make it unique
            agentNode.name = "agent-\(agentID)-\(pos.x)-\(pos.y)"
            
            // Update the label with the correct agent ID
            if let label = agentNode.childNode(withName: "//SKLabelNode") as? SKLabelNode {
                label.text = String(agentID.prefix(8))
            }
            
            // Add to the agent container
            agentContainer.addChild(agentNode)
            
            // Add a brief highlight animation when added
            let highlightAction = SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.2),
                SKAction.scale(to: 1.0, duration: 0.2)
            ])
            agentNode.run(highlightAction)
        }
        
        // Verify agent count after rendering
        if agentContainer.children.count != world.agents.count {
            print("⚠️ Warning: Agent count mismatch - World has \(world.agents.count) agents but rendered \(agentContainer.children.count) sprites")
        }
    }
}