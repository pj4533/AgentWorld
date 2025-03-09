//
//  AgentListView.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import SwiftUI
import AppKit

struct AgentListView: View {
    @ObservedObject var viewModel: SimulationViewModel
    
    // Create computed property that depends on the refresh trigger
    // This will force SwiftUI to update the view when agents change
    private var agentIds: [String] {
        // The access to refreshTrigger ensures view will update when it changes
        let _ = viewModel.agentListRefreshTrigger
        let agents = viewModel.world.agents
        let ids = Array(agents.keys.sorted())
        
        // Log the current agent IDs to help debug
        print("AgentListView refreshed with \(ids.count) agents: \(ids)")
        
        return ids
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Connected Agents")
                .font(.headline)
                .padding(.bottom, 4)
            
            ScrollView {
                if agentIds.isEmpty {
                    Text("No agents connected")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(agentIds, id: \.self) { agentId in
                        Button(action: {
                            viewModel.selectedAgentId = agentId
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color(nsColor: viewModel.world.agents[agentId]?.color ?? .gray))
                                    .frame(width: 12, height: 12)
                                
                                Text(agentId)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                                
                                if viewModel.selectedAgentId == agentId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(viewModel.selectedAgentId == agentId ? Color.gray.opacity(0.2) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(width: 180)
        }
        .padding(8)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

#Preview {
    AgentListView(viewModel: SimulationViewModel())
}