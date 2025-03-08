//
//  TimeDisplayView.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SwiftUI

struct TimeDisplayView: View {
    @ObservedObject var viewModel: SimulationViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Time Step: \(viewModel.currentTimeStep)")
                .font(.headline)
            Text("Day \(viewModel.currentTimeStep / 288), \(viewModel.formatTimeOfDay(timeStep: viewModel.currentTimeStep))")
                .font(.subheadline)
        }
        .padding(.horizontal)
    }
}

struct ProgressBarView: View {
    @ObservedObject var viewModel: SimulationViewModel
    
    var body: some View {
        HStack {
            Text("Next step:")
                .font(.caption)
                .frame(width: 60, alignment: .leading)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background of the progress bar
                    Rectangle()
                        .foregroundColor(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    // Filled portion of the progress bar
                    Rectangle()
                        .foregroundColor(viewModel.isSimulationRunning ? Color.blue : Color.gray)
                        .frame(width: max(geometry.size.width * viewModel.progressToNextStep, 0), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            // Time remaining display
            if viewModel.isSimulationRunning {
                Text("\(viewModel.getRemainingSeconds())s")
                    .font(.caption)
                    .frame(width: 40, alignment: .trailing)
            } else {
                Text("Paused")
                    .font(.caption)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.horizontal)
    }
}