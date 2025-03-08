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
        
        // Ensure the world scene has the latest time step
        // This is critical for play button functionality
        if scene.getCurrentTimeStep() != currentTimeStep {
            print("Updating scene to time step: \(currentTimeStep)")
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

struct ContentView: View {
    @State private var shouldRegenerateWorld = false
    @State private var currentTimeStep = 0
    @State private var isSimulationRunning = false
    @State private var simulationTimer: Task<Void, Never>? = nil
    @State private var timeStepInterval: TimeInterval = 60 // seconds between time steps
    @State private var minTimeStepInterval: TimeInterval = 5 // minimum interval in seconds
    @State private var maxTimeStepInterval: TimeInterval = 300 // maximum interval in seconds
    @State private var timeStepAdjustment: TimeInterval = 5 // amount to change by each button press
    
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
                HStack(spacing: 10) {
                    Button(action: {
                        toggleSimulation()
                    }) {
                        Image(systemName: isSimulationRunning ? "pause.fill" : "play.fill")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    
                    // Time step speed control with + and - buttons
                    HStack(spacing: 8) {
                        Button(action: {
                            decreaseTimeStepInterval()
                        }) {
                            Image(systemName: "minus")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .disabled(timeStepInterval <= minTimeStepInterval)
                        
                        // Display current time step interval
                        VStack(alignment: .center, spacing: 2) {
                            Text("\(Int(timeStepInterval))s")
                                .font(.headline)
                            Text("per step")
                                .font(.caption)
                        }
                        .frame(width: 80)
                        
                        Button(action: {
                            increaseTimeStepInterval()
                        }) {
                            Image(systemName: "plus")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .disabled(timeStepInterval >= maxTimeStepInterval)
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
        
        simulationTimer = Task { @MainActor in
            do {
                while !Task.isCancelled {
                    // Sleep for the specified interval
                    try await Task.sleep(for: .seconds(timeStepInterval))
                    
                    // Double check if we're still running and not cancelled
                    if !Task.isCancelled {
                        // Advance the time step on the main actor
                        advanceTimeStep()
                        
                        // Debug print to see if this is being called
                        print("Auto-advancing to time step: \(currentTimeStep)")
                    }
                }
            } catch {
                print("Simulation task was cancelled: \(error)")
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
    
    // Decrease the time step interval (speed up simulation - minus button)
    private func decreaseTimeStepInterval() {
        let newValue = timeStepInterval - timeStepAdjustment
        timeStepInterval = max(newValue, minTimeStepInterval)
        
        if isSimulationRunning {
            restartSimulation()
        }
        
        print("Time step interval decreased to \(timeStepInterval) seconds")
    }
    
    // Increase the time step interval (slow down simulation - plus button)
    private func increaseTimeStepInterval() {
        let newValue = timeStepInterval + timeStepAdjustment
        timeStepInterval = min(newValue, maxTimeStepInterval)
        
        if isSimulationRunning {
            restartSimulation()
        }
        
        print("Time step interval increased to \(timeStepInterval) seconds")
    }
}

#Preview {
    ContentView()
}
