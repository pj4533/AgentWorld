//
//  SimulationControlsView.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SwiftUI

struct SimulationControlsView: View {
    @ObservedObject var viewModel: SimulationViewModel
    
    var body: some View {
        HStack(spacing: 10) {
            // Play/Pause button
            Button(action: {
                viewModel.toggleSimulation()
            }) {
                Image(systemName: viewModel.isSimulationRunning ? "pause.fill" : "play.fill")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            
            // Time step speed control with + and - buttons
            IntervalControlView(viewModel: viewModel)
        }
        .padding(.horizontal)
    }
}

struct IntervalControlView: View {
    @ObservedObject var viewModel: SimulationViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                viewModel.decreaseTimeStepInterval()
            }) {
                Image(systemName: "minus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isMinTimeStepIntervalReached())
            
            // Display current time step interval
            VStack(alignment: .center, spacing: 2) {
                Text("\(Int(viewModel.timeStepInterval))s")
                    .font(.headline)
                Text("per step")
                    .font(.caption)
            }
            .frame(width: 80)
            
            Button(action: {
                viewModel.increaseTimeStepInterval()
            }) {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isMaxTimeStepIntervalReached())
        }
    }
}