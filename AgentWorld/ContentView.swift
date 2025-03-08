//
//  ContentView.swift
//  AgentWorld
//
//  Created by PJ Gray on 3/8/25.
//

import SwiftUI
import SpriteKit

struct SpriteKitContainer: NSViewRepresentable {
    func makeNSView(context: Context) -> SKView {
        let view = SKView()
        view.showsFPS = true
        view.showsNodeCount = true
        
        // Create and present the scene
        let scene = WorldScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .aspectFill
        view.presentScene(scene)
        
        return view
    }
    
    func updateNSView(_ nsView: SKView, context: Context) {
        // Update the view if needed
    }
}

struct ContentView: View {
    var body: some View {
        SpriteKitContainer()
            .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
