//
//  WorldRenderer.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit
import OSLog

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
    
    // Track the current zoom state to know when to switch to simplified agents
    private var currentZoomLevel: CGFloat = 1.0
    private var useSimplifiedAgents: Bool = false
    
    init(world: World, tileSize: CGFloat) {
        self.world = world
        self.tileSize = tileSize
        self.tileRenderer = TileRenderer(tileSize: tileSize)
        clearTileCache()
    }
    
    // Method to update zoom level and decide whether to use simplified agents
    public func updateZoom(_ zoomLevel: CGFloat) {
        // Only rebuild agent nodes if we cross the threshold between detailed and simplified
        let shouldUseSimplifiedAgents = zoomLevel > 0.7 // If scale > 0.7, we're zoomed out
        
        if shouldUseSimplifiedAgents != useSimplifiedAgents {
            // We've crossed the threshold, clear agent cache to rebuild with new style
            for (_, node) in agentNodeCache {
                node.removeAllActions()
                node.removeFromParent()
            }
            agentNodeCache.removeAll()
            useSimplifiedAgents = shouldUseSimplifiedAgents
        }
        
        currentZoomLevel = zoomLevel
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
        
        // Check if camera zoom has changed and update our zoom tracking
        if let cameraScale = scene.camera?.xScale {
            // Convert camera scale to zoom level
            let currentZoom = 1.0 / cameraScale
            updateZoom(cameraScale)
        }
        
        // Only render tiles if we haven't rendered them before or camera zoom changed significantly
        if !tilesRendered || scene.camera?.xScale != currentZoomLevel {
            renderTiles(in: scene)
            tilesRendered = true
        }
        
        // Always render agents (they can move)
        renderAgents(in: scene)
    }
    
    private func renderTiles(in scene: SKScene) {
        guard let tileContainer = tileContainer else { return }
        
        let logger = AppLogger(category: "WorldRenderer")
        
        // Remove all existing tile nodes first to ensure clean state
        tileContainer.removeAllChildren()
        
        // Calculate visible range based on camera position and zoom
        let visibleRows: [Int]
        let visibleCols: [Int]
        
        if let camera = scene.camera {
            // Calculate world coordinates of visible area with buffer
            let visibleRect = CGRect(
                x: camera.position.x - scene.size.width/(2*camera.xScale),
                y: camera.position.y - scene.size.height/(2*camera.yScale),
                width: scene.size.width/camera.xScale,
                height: scene.size.height/camera.yScale
            ).insetBy(dx: -tileSize*3, dy: -tileSize*3) // Larger buffer for tiles
            
            // Convert to grid coordinates
            let minX = max(0, Int(floor(visibleRect.minX / tileSize)))
            let maxX = min(World.size-1, Int(ceil(visibleRect.maxX / tileSize)))
            let minY = max(0, Int(floor((scene.size.height - visibleRect.maxY) / tileSize)))
            let maxY = min(World.size-1, Int(ceil((scene.size.height - visibleRect.minY) / tileSize)))
            
            visibleRows = Array(minY...maxY)
            visibleCols = Array(minX...maxX)
            
            logger.debug("Rendering tiles in visible range: rows \(minY)-\(maxY), cols \(minX)-\(maxX)")
        } else {
            // If no camera, render everything
            visibleRows = Array(0..<World.size)
            visibleCols = Array(0..<World.size)
        }
        
        // Create and place tile sprites only for visible tiles
        for y in visibleRows {
            for x in visibleCols {
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
        
        let logger = AppLogger(category: "WorldRenderer")
        
        // First, log debug info about all agents being rendered
        logger.debug("Rendering \(world.agents.count) agents in the world")
        
        // Keep existing agents, only remove/add ones that changed
        let currentAgentIds = Set(world.agents.keys)
        let cachedAgentIds = Set(agentNodeCache.keys)
        
        // Remove agents that no longer exist
        for agentId in cachedAgentIds.subtracting(currentAgentIds) {
            if let node = agentNodeCache[agentId] {
                node.removeFromParent()
                node.removeAllActions()
                agentNodeCache.removeValue(forKey: agentId)
                logger.debug("Removed agent node for \(agentId)")
            }
        }
        
        // Update or create agents
        for (agentId, agentInfo) in world.agents {
            let pos = agentInfo.position
            let newPosition = CGPoint(
                x: CGFloat(pos.x) * tileSize + tileSize/2,
                y: scene.size.height - (CGFloat(pos.y) * tileSize + tileSize/2) // Flip Y-axis
            )
            
            // Skip rendering if not visible (with buffer)
            if !isPositionVisible(newPosition, in: scene) {
                // If we have a cached node for an off-screen agent, remove it temporarily
                if let existingNode = agentNodeCache[agentId], existingNode.parent != nil {
                    existingNode.removeFromParent()
                    logger.debug("Agent \(agentId) is off-screen, temporarily removing node")
                }
                continue
            }
            
            let agentNode: SKSpriteNode
            
            if let existingNode = agentNodeCache[agentId], existingNode.parent == nil {
                // Reuse existing cached node that's not on screen
                agentNode = existingNode
                agentContainer.addChild(agentNode)
                logger.debug("Reusing cached node for agent \(agentId)")
            } else if let existingNode = agentNodeCache[agentId] {
                // Already on screen, just update existing node
                agentNode = existingNode
                logger.debug("Updating existing node for agent \(agentId)")
            } else {
                // Create new node only if needed (simplified based on zoom level)
                agentNode = tileRenderer.createAgentNode(
                    withColor: agentInfo.color,
                    size: CGSize(width: tileSize, height: tileSize),
                    simplified: useSimplifiedAgents
                )
                agentNodeCache[agentId] = agentNode
                agentContainer.addChild(agentNode)
                
                // Only add highlight animation for new nodes
                let highlightAction = SKAction.sequence([
                    SKAction.scale(to: 1.3, duration: 0.2),
                    SKAction.scale(to: 1.0, duration: 0.2)
                ])
                agentNode.run(highlightAction)
                
                logger.debug("Created new node for agent \(agentId)")
            }
            
            // Update position and name
            agentNode.position = newPosition
            agentNode.name = "agent-\(agentId)-\(pos.x)-\(pos.y)"
            
            // Update the label with the correct agent ID
            if let label = agentNode.childNode(withName: "//SKLabelNode") as? SKLabelNode {
                label.text = String(agentId.prefix(8))
            }
        }
        
        // Verify agent count is correct
        let visibleAgentCount = agentContainer.children.count
        let expectedVisibleCount = world.agents.filter { 
            isPositionVisible(CGPoint(
                x: CGFloat($0.value.position.x) * tileSize + tileSize/2,
                y: scene.size.height - (CGFloat($0.value.position.y) * tileSize + tileSize/2)
            ), in: scene) 
        }.count
        
        if visibleAgentCount != expectedVisibleCount {
            logger.error("Agent count mismatch - Expected \(expectedVisibleCount) visible agents but rendered \(visibleAgentCount) sprites")
        }
    }
    
    // Helper method to determine if a position is visible on screen (with buffer)
    private func isPositionVisible(_ position: CGPoint, in scene: SKScene) -> Bool {
        guard let camera = scene.camera else { return true }
        
        let visibleRect = CGRect(
            x: camera.position.x - scene.size.width/(2*camera.xScale),
            y: camera.position.y - scene.size.height/(2*camera.yScale),
            width: scene.size.width/camera.xScale,
            height: scene.size.height/camera.yScale
        )
        
        // Add a buffer zone (2 tiles in each direction)
        let bufferRect = visibleRect.insetBy(dx: -tileSize*2, dy: -tileSize*2)
        return bufferRect.contains(position)
    }
}