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
    
    init(world: World, tileSize: CGFloat) {
        self.world = world
        self.tileSize = tileSize
        self.tileRenderer = TileRenderer(tileSize: tileSize)
        clearTileCache()
    }
    
    /// Clears the tile node cache
    public func clearTileCache() {
        tileNodeCache = Array(repeating: Array(repeating: nil, count: World.size), count: World.size)
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
                
                // Add to scene
                scene.addChild(tileNode)
            }
        }
    }
}