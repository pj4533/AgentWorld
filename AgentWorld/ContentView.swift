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
            
            // Main world view
            SpriteKitContainer(
                shouldRegenerateWorld: $viewModel.shouldRegenerateWorld,
                currentTimeStep: $viewModel.currentTimeStep
            )
            .frame(width: 640, height: 640)
            .aspectRatio(1.0, contentMode: .fit)
            
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
