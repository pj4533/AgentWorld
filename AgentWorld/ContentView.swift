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
    @Binding var currentTimeStep: Int
    
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
        
        // Update the world to the current time step
        scene.updateToTimeStep(currentTimeStep)
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
    @State private var currentTimeStep = 0
    @State private var isSimulationRunning = false
    @State private var simulationTimer: Task<Void, Never>? = nil
    @State private var timeStepInterval: TimeInterval = 60 // seconds between time steps
    
    var body: some View {
        VStack {
            // Top bar with time display
            HStack {
                VStack(alignment: .leading) {
                    Text("Time Step: \(currentTimeStep)")
                        .font(.headline)
                    Text("Day \(currentTimeStep / 288), \(formatTimeOfDay(timeStep: currentTimeStep))")
                        .font(.subheadline)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Simulation control buttons
                HStack {
                    Button(action: {
                        toggleSimulation()
                    }) {
                        Image(systemName: isSimulationRunning ? "pause.fill" : "play.fill")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    
                    // Time step speed control
                    Picker("Speed", selection: $timeStepInterval) {
                        Text("Fast").tag(15.0)
                        Text("Normal").tag(60.0)
                        Text("Slow").tag(120.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: timeStepInterval) { _, _ in
                        if isSimulationRunning {
                            restartSimulation()
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
            
            // Main world view
            SpriteKitContainer(
                shouldRegenerateWorld: $shouldRegenerateWorld,
                currentTimeStep: $currentTimeStep
            )
            .frame(width: 640, height: 640)
            .aspectRatio(1.0, contentMode: .fit)
            
            // Bottom controls
            HStack {
                Button("Generate New World") {
                    shouldRegenerateWorld = true
                }
                .padding()
                
                Button("Step Forward") {
                    advanceTimeStep()
                }
                .padding()
                .disabled(isSimulationRunning)
            }
        }
        .onDisappear {
            cancelSimulation()
        }
    }
    
    // Format time step into a time of day (HH:MM)
    private func formatTimeOfDay(timeStep: Int) -> String {
        // Each day has 288 time steps (24 hours * 60 minutes / 5 minutes per step)
        let timeOfDayInMinutes = (timeStep % 288) * 5
        let hours = timeOfDayInMinutes / 60
        let minutes = timeOfDayInMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    // Toggle simulation running state
    private func toggleSimulation() {
        isSimulationRunning.toggle()
        
        if isSimulationRunning {
            startSimulation()
        } else {
            cancelSimulation()
        }
    }
    
    // Start the simulation timer
    private func startSimulation() {
        cancelSimulation() // Cancel any existing timer
        
        simulationTimer = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(timeStepInterval * 1_000_000_000))
                    if !Task.isCancelled {
                        await MainActor.run {
                            advanceTimeStep()
                        }
                    }
                } catch {
                    break
                }
            }
        }
    }
    
    // Cancel the simulation timer
    private func cancelSimulation() {
        simulationTimer?.cancel()
        simulationTimer = nil
    }
    
    // Restart the simulation after changing interval
    private func restartSimulation() {
        cancelSimulation()
        startSimulation()
    }
    
    // Advance the simulation by one time step
    private func advanceTimeStep() {
        currentTimeStep += 1
        // Additional logic for time step advancement could go here
    }
}

#Preview {
    ContentView()
}
