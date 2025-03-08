//
//  ContentView.swift
//  AgentWorld
//
//  Created by PJ Gray on 3/8/25.
//

import SwiftUI
import SpriteKit

struct SpriteKitContainer: NSViewRepresentable {
    @Binding var shouldRegenerateWorld: Bool
    
    init(shouldRegenerateWorld: Binding<Bool> = .constant(false)) {
        self._shouldRegenerateWorld = shouldRegenerateWorld
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
        // Check if we should regenerate the world
        if shouldRegenerateWorld {
            if let scene = context.coordinator.scene {
                scene.regenerateWorld()
            }
            // Reset the flag
            DispatchQueue.main.async {
                shouldRegenerateWorld = false
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

struct ContentView: View {
    @State private var shouldRegenerateWorld = false
    
    var body: some View {
        VStack {
            SpriteKitContainer(shouldRegenerateWorld: $shouldRegenerateWorld)
                .frame(width: 640, height: 640)
                .aspectRatio(1.0, contentMode: .fit)
            
            Button("Generate New World") {
                shouldRegenerateWorld = true
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
