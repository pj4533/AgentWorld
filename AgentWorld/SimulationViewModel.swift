//
//  SimulationViewModel.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation
import Combine
import OSLog
import AppKit

class SimulationViewModel: ObservableObject {
    @Published var currentTimeStep: Int = 0
    @Published var shouldRegenerateWorld: Bool = false
    @Published var isSimulationRunning: Bool = false
    @Published var timeStepInterval: TimeInterval = 60 // seconds between time steps
    @Published var progressToNextStep: Double = 0.0 // Progress indicator (0.0 - 1.0)
    @Published var world: World
    @Published var selectedAgentId: String? = nil
    @Published var agentListRefreshTrigger = false  // Used to trigger SwiftUI refreshes
    
    private var simulationTimer: Task<Void, Never>? = nil
    private var progressTimer: Timer? = nil
    private var lastStepTime: Date? = nil
    private var agentChangeObserver: NSObjectProtocol?
    
    private let minTimeStepInterval: TimeInterval = 5 // minimum interval in seconds
    private let maxTimeStepInterval: TimeInterval = 300 // maximum interval in seconds
    private let timeStepAdjustment: TimeInterval = 5 // amount to change by each button press
    private let progressUpdateInterval: TimeInterval = 0.1 // Update progress 10 times per second
    
    private let logger = AppLogger(category: "SimulationViewModel")
    
    // MARK: - Public Interface
    
    init() {
        // Initialize with a default world
        self.world = World.generateWorld()
    }
    
    func toggleSimulation() {
        isSimulationRunning.toggle()
        
        if isSimulationRunning {
            startSimulation()
        } else {
            cancelSimulation()
        }
    }
    
    func regenerateWorld() {
        shouldRegenerateWorld = true
        world = World.generateWorld()
    }
    
    func advanceTimeStep() {
        currentTimeStep += 1
        
        // If not running in auto mode but manually stepped, update the progress display
        if !isSimulationRunning {
            progressToNextStep = 0.0
        } else {
            // Reset the progress bar and last step time for continuous running
            progressToNextStep = 0.0
            lastStepTime = Date()
        }
    }
    
    func decreaseTimeStepInterval() {
        let newValue = timeStepInterval - timeStepAdjustment
        timeStepInterval = max(newValue, minTimeStepInterval)
        
        if isSimulationRunning {
            restartSimulation()
        }
        
        logger.info("Time step interval decreased to \(timeStepInterval) seconds")
    }
    
    func increaseTimeStepInterval() {
        let newValue = timeStepInterval + timeStepAdjustment
        timeStepInterval = min(newValue, maxTimeStepInterval)
        
        if isSimulationRunning {
            restartSimulation()
        }
        
        logger.info("Time step interval increased to \(timeStepInterval) seconds")
    }
    
    func cleanup() {
        cancelSimulation()
        stopProgressTimer()
        
        // Remove the agent change observer
        if let observer = agentChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            agentChangeObserver = nil
        }
    }
    
    func initialize() {
        // Initialize the timer if simulation is already running
        if isSimulationRunning {
            startProgressTimer()
        }
        
        // Listen for agent connection/disconnection events
        agentChangeObserver = NotificationCenter.default.addObserver(
            forName: .agentsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // Update our world reference if provided
            if let updatedWorld = notification.object as? World {
                self.world = updatedWorld
            }
            
            // Toggle the refresh trigger to force SwiftUI list to refresh
            self.agentListRefreshTrigger.toggle()
            self.logger.debug("🔄 Agent list refresh triggered by notification - now have \(self.world.agents.count) agents")
        }
    }
    
    func formatTimeOfDay(timeStep: Int) -> String {
        // Each day has 288 time steps (24 hours * 60 minutes / 5 minutes per step)
        let timeOfDayInMinutes = (timeStep % 288) * 5
        let hours = timeOfDayInMinutes / 60
        let minutes = timeOfDayInMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    func getRemainingSeconds() -> Int {
        return Int(timeStepInterval * (1.0 - progressToNextStep))
    }
    
    func isMinTimeStepIntervalReached() -> Bool {
        return timeStepInterval <= minTimeStepInterval
    }
    
    func isMaxTimeStepIntervalReached() -> Bool {
        return timeStepInterval >= maxTimeStepInterval
    }
    
    // MARK: - Private Methods
    
    private func startSimulation() {
        cancelSimulation() // Cancel any existing timer
        
        // Start the progress timer to update the progress bar
        startProgressTimer()
        
        // Reset last step time and progress
        lastStepTime = Date()
        progressToNextStep = 0.0
        
        simulationTimer = Task { @MainActor in
            do {
                while !Task.isCancelled {
                    // Sleep for the specified interval
                    try await Task.sleep(for: .seconds(timeStepInterval))
                    
                    // Double check if we're still running and not cancelled
                    if !Task.isCancelled {
                        // Advance the time step on the main actor
                        advanceTimeStep()
                        
                        // Reset the progress bar and last step time
                        progressToNextStep = 0.0
                        lastStepTime = Date()
                        
                        // Debug print to see if this is being called
                        logger.debug("Auto-advancing to time step: \(currentTimeStep)")
                    }
                }
            } catch {
                logger.error("Simulation task was cancelled: \(error.localizedDescription)")
            }
        }
    }
    
    private func startProgressTimer() {
        stopProgressTimer() // Stop any existing timer
        
        // Create a timer that updates the progress bar
        progressTimer = Timer.scheduledTimer(withTimeInterval: progressUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self, 
                  let lastStepTime = self.lastStepTime, 
                  self.isSimulationRunning else { return }
            
            // Calculate progress (0.0 to 1.0)
            let elapsedTime = Date().timeIntervalSince(lastStepTime)
            self.progressToNextStep = min(elapsedTime / self.timeStepInterval, 1.0)
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func cancelSimulation() {
        simulationTimer?.cancel()
        simulationTimer = nil
        stopProgressTimer()
    }
    
    private func restartSimulation() {
        cancelSimulation()
        startSimulation()
    }
}