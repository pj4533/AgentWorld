//
//  WorldScene+Input.swift
//  AgentWorld
//
//  Created by Claude on 3/9/25.
//

import SpriteKit

// Extension to handle user input-related functionality
extension WorldScene {
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        // Start panning
        isDragging = true
        
        // Initialize at current position (no movement yet)
        cameraTargetPosition = cameraNode.position
        hasTargetPosition = true
        
        // Only pass to input handler for actual clicks
        if event.clickCount > 0 {
            inputHandler.handleMouseDown(with: event, in: self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        // Skip if we're not in dragging mode
        guard isDragging else { return }
        
        // Disable agent tracking when manually dragging
        isTrackingAgent = false
        
        // Filter out tiny movements that can cause jitter
        let dx = event.deltaX
        let dy = event.deltaY
        
        // Apply sensitivity - higher = faster panning
        let sensitivity: CGFloat = 2.0
        
        // Calculate new target position based on current target (not current camera position)
        let newTargetX = cameraTargetPosition.x - dx * sensitivity / currentZoom
        let newTargetY = cameraTargetPosition.y + dy * sensitivity / currentZoom
        
        // Update target position with constraints
        cameraTargetPosition = constrainPositionToBounds(CGPoint(x: newTargetX, y: newTargetY))
    }
    
    override func mouseUp(with event: NSEvent) {
        // End dragging mode
        isDragging = false
        
        // If user was dragging, disable agent tracking
        if event.deltaX != 0 || event.deltaY != 0 {
            isTrackingAgent = false
        }
        
        // Stop targeting after a short delay to allow smooth finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.hasTargetPosition = false
        }
    }
    
    // MARK: - Scroll & Keyboard Events
    
    func handleScrollWheel(with event: NSEvent) {
        logger.debug("Direct scroll wheel handling with scrollingDeltaY: \(event.scrollingDeltaY)")
        
        // Only process if there's actual scroll delta
        if abs(event.scrollingDeltaY) > 0.1 {
            // Reversed direction - now scrolling up (negative scrollingDeltaY) means zoom out
            let zoomDirection: CGFloat = event.scrollingDeltaY > 0 ? 1 : -1
            
            // Significantly faster zoom amount for scroll wheel
            let zoomAmount: CGFloat = 0.3 * zoomDirection
            
            // Get mouse location in scene coordinates to zoom toward that point
            let mouseLocation = event.location(in: self)
            
            // Apply smoother zooming with larger increments
            smoothZoom(by: zoomAmount, towardPoint: mouseLocation)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        // Get the pressed key
        if let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "=", "+": // Zoom in with plus key
                // For keyboard zoom, use center of screen
                let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
                smoothZoom(by: 1.0, towardPoint: centerPoint)
            case "-", "_": // Zoom out with minus key
                let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
                smoothZoom(by: -1.0, towardPoint: centerPoint)
            case "0":      // Reset zoom
                resetZoom()
            default:
                // Pass other keys to default handler
                super.keyDown(with: event)
            }
        }
    }
}