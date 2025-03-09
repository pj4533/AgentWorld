//
//  SpriteKitContainer.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SwiftUI
import SpriteKit
import OSLog

// Custom SKView subclass to properly handle scroll wheel events
class ZoomableSkView: SKView {
    private let logger = AppLogger(category: "ZoomableSkView")
    
    override func scrollWheel(with event: NSEvent) {
        logger.debug("View received scroll: \(event.scrollingDeltaY)")
        
        // Pass event to the scene
        if let worldScene = self.scene as? WorldScene {
            // Call directly to ensure processing
            worldScene.handleScrollWheel(with: event)
        }
        
        // Don't call super to avoid duplicate event processing
        // super.scrollWheel(with: event)
    }
}

struct SpriteKitContainer: NSViewRepresentable {
    @Binding var shouldRegenerateWorld: Bool
    @Binding var currentTimeStep: Int
    @ObservedObject var viewModel: SimulationViewModel
    private let logger = AppLogger(category: "SpriteKitContainer")
    
    init(shouldRegenerateWorld: Binding<Bool> = .constant(false),
         currentTimeStep: Binding<Int> = .constant(0),
         viewModel: SimulationViewModel) {
        self._shouldRegenerateWorld = shouldRegenerateWorld
        self._currentTimeStep = currentTimeStep
        self.viewModel = viewModel
    }
    
    func makeNSView(context: Context) -> ZoomableSkView {
        // Use our custom SKView subclass
        let view = ZoomableSkView()
        view.showsFPS = true
        view.showsNodeCount = true
        
        // Enable all necessary settings for input handling
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.wantsLayer = true
        
        // Create and present the scene with square dimensions
        let scene = WorldScene(size: CGSize(width: 640, height: 640))
        scene.scaleMode = .aspectFill
        scene.setWorld(viewModel.world)
        
        // Make sure user interaction is enabled at scene level
        scene.isUserInteractionEnabled = true
        
        // Present the scene
        view.presentScene(scene)
        
        // Store the scene in the coordinator
        context.coordinator.scene = scene
        
        return view
    }
    
    func updateNSView(_ nsView: ZoomableSkView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        
        // Check if we should regenerate the world
        if shouldRegenerateWorld {
            // Set the new world from the viewModel
            scene.setWorld(viewModel.world)
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
        
        // Add a debugging hook to sync the viewModel's world with the scene's world
        // This helps ensure the agent list is always up-to-date
        DispatchQueue.main.async {
            if !self.viewModel.world.agents.keys.sorted().elementsEqual(scene.world.agents.keys.sorted()) {
                self.logger.debug("👉 Syncing ViewModel world with scene world - \(scene.world.agents.count) agents")
                self.viewModel.world = scene.world
                // Force the agent list to refresh
                self.viewModel.agentListRefreshTrigger.toggle()
            }
        }
        
        // Handle focusing on a selected agent
        if let selectedAgentId = viewModel.selectedAgentId {
            // Focus on the agent
            scene.focusOnAgent(id: selectedAgentId)
            
            // Clear the selection to avoid repeated focusing
            DispatchQueue.main.async {
                viewModel.selectedAgentId = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var scene: WorldScene?
    }
}