//
//  ContentView.swift
//  AgentWorld
//
//  Created by PJ Gray on 3/8/25.
//

import SwiftUI
import OSLog

struct ContentView: View {
    @StateObject private var viewModel = SimulationViewModel()
    private let logger = AppLogger(category: "ContentView")
    
    var body: some View {
        VStack {
            // Top bar with time display and controls
            VStack(spacing: 8) {
                HStack {
                    // Time step display
                    TimeDisplayView(viewModel: viewModel)
                    
                    Spacer()
                    
                    // Simulation control buttons
                    SimulationControlsView(viewModel: viewModel)
                }
                
                // Progress bar for next time step
                ProgressBarView(viewModel: viewModel)
            }
            .padding(.top)
            
            // Main content with agent list and world view
            HStack(alignment: .top, spacing: 0) {
                // Agent list on the left
                AgentListView(viewModel: viewModel)
                    .frame(width: 200)
                    .padding(.trailing, 8)
                
                // Main world view
                SpriteKitContainer(
                    shouldRegenerateWorld: $viewModel.shouldRegenerateWorld,
                    currentTimeStep: $viewModel.currentTimeStep,
                    viewModel: viewModel
                )
                .frame(width: 640, height: 640)
                .aspectRatio(1.0, contentMode: .fit)
            }
            
            // Navigation instructions
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Map Controls:").bold()
                    Text("• Drag to pan")
                    Text("• Scroll wheel to zoom")
                    Text("• +/- keys to zoom in/out")
                    Text("• 0 key to reset zoom")
                    Text("• Click agent in list to focus")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                
                Spacer()
                
                // Bottom controls
                HStack {
                    Button("Generate New World") {
                        viewModel.regenerateWorld()
                    }
                    .padding()
                    
                    Button("Step Forward") {
                        viewModel.advanceTimeStep()
                    }
                    .padding()
                    .disabled(viewModel.isSimulationRunning)
                }
            }
        }
        .onAppear {
            viewModel.initialize()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

#Preview {
    ContentView()
}
