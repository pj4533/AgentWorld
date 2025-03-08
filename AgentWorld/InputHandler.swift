//
//  InputHandler.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SpriteKit

protocol InputHandlerDelegate: AnyObject {
    func inputHandler(_ handler: InputHandler, didClickAtPosition position: CGPoint)
}

class InputHandler {
    weak var delegate: InputHandlerDelegate?
    
    init(delegate: InputHandlerDelegate? = nil) {
        self.delegate = delegate
    }
    
    func handleMouseDown(with event: NSEvent, in scene: SKScene) {
        let location = event.location(in: scene)
        print("Click at \(location)")
        
        delegate?.inputHandler(self, didClickAtPosition: location)
    }
}