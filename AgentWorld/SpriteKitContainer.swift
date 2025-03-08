//
//  SpriteKitContainer.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SwiftUI
import SpriteKit
import OSLog

struct SpriteKitContainer: NSViewRepresentable {
    @Binding var shouldRegenerateWorld: Bool
    @Binding var currentTimeStep: Int
    private let logger = AppLogger(category: "SpriteKitContainer")
    
    init(shouldRegenerateWorld: Binding<Bool> = .constant(false),
         currentTimeStep: Binding<Int> = .constant(0)) {
        self._shouldRegenerateWorld = shouldRegenerateWorld
        self._currentTimeStep = currentTimeStep
    }
    
    func makeNSView(context: Context) -> SKView {
        let view = SKView()
        view.showsFPS = true
        view.showsNodeCount = true
        
        // Create and present the scene with square dimensions
        let scene = WorldScene(size: CGSize(width: 640, height: 640))
        scene.scaleMode = .aspectFill
        view.presentScene(scene)
        
        // Store the scene in the coordinator
        context.coordinator.scene = scene
        
        return view
    }
    
    func updateNSView(_ nsView: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        
        // Check if we should regenerate the world
        if shouldRegenerateWorld {
            scene.regenerateWorld()
            
            // Reset the flag
            DispatchQueue.main.async {
                shouldRegenerateWorld = false
                // Also reset the time step in ContentView to match the reset in WorldScene
                currentTimeStep = 0
            }
        }
        
        // Ensure the world scene has the latest time step
        // This is critical for play button functionality
        if scene.getCurrentTimeStep() != currentTimeStep {
            logger.debug("Updating scene to time step: \(currentTimeStep)")
            scene.updateToTimeStep(currentTimeStep)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var scene: WorldScene?
    }
}