//
//  TileRendering.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit

class TileRenderer {
    private let tileSize: CGFloat
    
    init(tileSize: CGFloat) {
        self.tileSize = tileSize
    }
    
    func createTileNode(for tileType: TileType, size: CGSize) -> SKSpriteNode {
        let node = SKSpriteNode(color: tileType.color, size: size)
        
        // Add texture pattern to the node
        switch tileType {
        case .grass:
            addGrassTexture(to: node)
        case .trees:
            addTreesTexture(to: node)
        case .mountains:
            addMountainsTexture(to: node)
        case .water:
            addWaterTexture(to: node)
        case .swamp:
            addSwampTexture(to: node)
        case .desert:
            addDesertTexture(to: node)
        }
        
        return node
    }
    
    private func addGrassTexture(to node: SKSpriteNode) {
        // Add grass blade shapes for better visibility
        let grassCount = Int.random(in: 4...8)
        for _ in 0..<grassCount {
            // Create a grass blade path
            let bladePath = CGMutablePath()
            let startX = CGFloat.random(in: -node.size.width/2 + tileSize*0.1...node.size.width/2 - tileSize*0.1)
            let startY = CGFloat.random(in: -node.size.height/2 + tileSize*0.1...node.size.height/2 - tileSize*0.1)
            
            // Base of grass blade
            bladePath.move(to: CGPoint(x: startX, y: startY))
            
            // Curved top of grass blade
            let height = tileSize * CGFloat.random(in: 0.15...0.25)
            let curveOffset = tileSize * CGFloat.random(in: 0.05...0.15) * (Bool.random() ? 1 : -1)
            
            bladePath.addQuadCurve(
                to: CGPoint(x: startX, y: startY + height),
                control: CGPoint(x: startX + curveOffset, y: startY + height*0.7)
            )
            
            let blade = SKShapeNode(path: bladePath)
            blade.strokeColor = NSColor(red: 0.8, green: 0.9, blue: 0.0, alpha: 1.0) // Yellowish green
            blade.lineWidth = tileSize * 0.08
            blade.lineCap = .round
            
            node.addChild(blade)
        }
        
        // Add a few darker patches of grass for texture
        let patchCount = Int.random(in: 2...4)
        for _ in 0..<patchCount {
            let patch = SKShapeNode(circleOfRadius: tileSize * 0.1)
            patch.fillColor = NSColor(red: 0.0, green: 0.4, blue: 0.0, alpha: 1.0) // Darker green
            patch.strokeColor = .clear
            patch.alpha = 0.4
            patch.position = CGPoint(
                x: CGFloat.random(in: -node.size.width/2 + tileSize*0.1...node.size.width/2 - tileSize*0.1),
                y: CGFloat.random(in: -node.size.height/2 + tileSize*0.1...node.size.height/2 - tileSize*0.1)
            )
            node.addChild(patch)
        }
    }
    
    private func addTreesTexture(to node: SKSpriteNode) {
        // Add tree-like shapes
        let treesCount = Int.random(in: 2...4)
        for _ in 0..<treesCount {
            // Tree trunk
            let trunk = SKShapeNode(rectOf: CGSize(width: tileSize * 0.1, height: tileSize * 0.3))
            trunk.fillColor = NSColor.brown
            trunk.strokeColor = .clear
            trunk.position = CGPoint(
                x: CGFloat.random(in: -node.size.width/3...node.size.width/3),
                y: CGFloat.random(in: -node.size.height/3...node.size.height/3)
            )
            
            // Tree foliage
            let foliage = SKShapeNode(circleOfRadius: tileSize * 0.2)
            foliage.fillColor = NSColor(red: 0.0, green: 0.35, blue: 0.0, alpha: 1.0) // Very dark green
            foliage.strokeColor = .clear
            foliage.position = CGPoint(x: 0, y: trunk.frame.size.height/2 + foliage.frame.size.height/3)
            
            trunk.addChild(foliage)
            node.addChild(trunk)
        }
    }
    
    private func addMountainsTexture(to node: SKSpriteNode) {
        // Add mountain peak
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: -node.size.width/2, y: -node.size.height/3))
        trianglePath.addLine(to: CGPoint(x: 0, y: node.size.height/2))
        trianglePath.addLine(to: CGPoint(x: node.size.width/2, y: -node.size.height/3))
        trianglePath.closeSubpath()
        
        let mountain = SKShapeNode(path: trianglePath)
        mountain.fillColor = NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0) // Light gray
        mountain.strokeColor = .clear
        
        // Add snow cap
        let snowCapPath = CGMutablePath()
        snowCapPath.move(to: CGPoint(x: -node.size.width/6, y: node.size.height/6))
        snowCapPath.addLine(to: CGPoint(x: 0, y: node.size.height/2))
        snowCapPath.addLine(to: CGPoint(x: node.size.width/6, y: node.size.height/6))
        snowCapPath.closeSubpath()
        
        let snowCap = SKShapeNode(path: snowCapPath)
        snowCap.fillColor = .white
        snowCap.strokeColor = .clear
        
        node.addChild(mountain)
        node.addChild(snowCap)
    }
    
    private func addWaterTexture(to node: SKSpriteNode) {
        // Add wave lines
        for i in 0..<3 {
            let waveHeight = CGFloat.random(in: 0.1...0.3)
            let wavePath = CGMutablePath()
            
            let yPos = CGFloat(i) * node.size.height/3 - node.size.height/2 + node.size.height/6
            
            wavePath.move(to: CGPoint(x: -node.size.width/2, y: yPos))
            wavePath.addQuadCurve(
                to: CGPoint(x: node.size.width/2, y: yPos),
                control: CGPoint(x: 0, y: yPos + node.size.height * waveHeight)
            )
            
            let wave = SKShapeNode(path: wavePath)
            wave.strokeColor = NSColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0) // Light blue
            wave.lineWidth = 1
            
            node.addChild(wave)
        }
    }
    
    private func addSwampTexture(to node: SKSpriteNode) {
        // Add swamp vegetation and bubbles
        
        // Add murky patches
        let patchesCount = Int.random(in: 2...4)
        for _ in 0..<patchesCount {
            let patch = SKShapeNode(circleOfRadius: tileSize * CGFloat.random(in: 0.1...0.25))
            patch.fillColor = NSColor(red: 0.0, green: 0.3, blue: 0.0, alpha: 1.0) // Dark green for swamp
            patch.strokeColor = .clear
            patch.alpha = 0.6
            patch.position = CGPoint(
                x: CGFloat.random(in: -node.size.width/2...node.size.width/2),
                y: CGFloat.random(in: -node.size.height/2...node.size.height/2)
            )
            node.addChild(patch)
        }
        
        // Add small bubbles
        let bubblesCount = Int.random(in: 3...6)
        for _ in 0..<bubblesCount {
            let bubble = SKShapeNode(circleOfRadius: tileSize * CGFloat.random(in: 0.02...0.04))
            bubble.fillColor = .white
            bubble.strokeColor = .clear
            bubble.alpha = 0.5
            bubble.position = CGPoint(
                x: CGFloat.random(in: -node.size.width/2...node.size.width/2),
                y: CGFloat.random(in: -node.size.height/2...node.size.height/2)
            )
            node.addChild(bubble)
        }
    }
    
    private func addDesertTexture(to node: SKSpriteNode) {
        // Add sand dune shapes
        let dunePath = CGMutablePath()
        dunePath.move(to: CGPoint(x: -node.size.width/2, y: -node.size.height/6))
        dunePath.addQuadCurve(
            to: CGPoint(x: 0, y: -node.size.height/6),
            control: CGPoint(x: -node.size.width/4, y: node.size.height/6)
        )
        dunePath.addQuadCurve(
            to: CGPoint(x: node.size.width/2, y: -node.size.height/6),
            control: CGPoint(x: node.size.width/4, y: -node.size.height/3)
        )
        
        let dune = SKShapeNode(path: dunePath)
        dune.strokeColor = NSColor(red: 0.9, green: 0.7, blue: 0.0, alpha: 1.0) // Orange-ish yellow
        dune.lineWidth = 2
        
        // Add small dots for sand texture
        let dotsCount = Int.random(in: 5...10)
        for _ in 0..<dotsCount {
            let dot = SKShapeNode(circleOfRadius: tileSize * 0.02)
            dot.fillColor = NSColor(red: 0.8, green: 0.6, blue: 0.3, alpha: 1.0) // Brownish yellow
            dot.strokeColor = .clear
            dot.position = CGPoint(
                x: CGFloat.random(in: -node.size.width/2...node.size.width/2),
                y: CGFloat.random(in: -node.size.height/2...node.size.height/2)
            )
            node.addChild(dot)
        }
        
        node.addChild(dune)
    }
}