//
//  InputHandler.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit
import OSLog

protocol InputHandlerDelegate: AnyObject {
    func inputHandler(_ handler: InputHandler, didClickAtPosition position: CGPoint)
}

class InputHandler {
    weak var delegate: InputHandlerDelegate?
    private let logger = AppLogger(category: "InputHandler")
    
    init(delegate: InputHandlerDelegate? = nil) {
        self.delegate = delegate
    }
    
    func handleMouseDown(with event: NSEvent, in scene: SKScene) {
        // Convert screen position to scene position (accounts for camera position and zoom)
        let location = event.location(in: scene)
        logger.debug("Click at \(location)")
        
        // Inform delegate of click position
        delegate?.inputHandler(self, didClickAtPosition: location)
    }
    
    /// Converts a world position (in tile coordinates) to a scene position (in points)
    func convertToScenePosition(worldX: Int, worldY: Int, tileSize: CGFloat, in scene: SKScene) -> CGPoint {
        return CGPoint(
            x: CGFloat(worldX) * tileSize + tileSize/2,
            y: scene.size.height - (CGFloat(worldY) * tileSize + tileSize/2)
        )
    }
    
    /// Converts a scene position (in points) to a world position (in tile coordinates)
    func convertToWorldPosition(scenePosition: CGPoint, tileSize: CGFloat, in scene: SKScene) -> (Int, Int) {
        let x = Int(scenePosition.x / tileSize)
        let y = Int((scene.size.height - scenePosition.y) / tileSize)
        return (x, y)
    }
}