//
//  TestHelpers.swift
//  AgentWorldTests
//
//  Created by Claude on 3/9/25.
//

import Foundation
import Testing
@testable import AgentWorld

// Helper function for standardized async testing across all test files
func waitForAsyncCompletion(_ block: (@escaping () -> Void) -> Void, timeout: TimeInterval = 10.0) -> Bool {
    let semaphore = DispatchSemaphore(value: 0)
    
    block {
        semaphore.signal()
    }
    
    // Use a longer timeout for reliability
    let result = semaphore.wait(timeout: .now() + timeout)
    return result == .success
}

// Helper for creating isolated test worlds
func createIsolatedTestWorld(agentId: String? = nil) -> (World, String) {
    let world = World()
    
    // Setup known tiles
    for y in 0..<World.size {
        for x in 0..<World.size {
            world.tiles[y][x] = .grass
        }
    }
    
    // Use provided agent ID or generate a unique one
    let uniqueId = agentId ?? "test-agent-\(UUID().uuidString)"
    
    // Place agent at a fixed position for predictability
    world.agents[uniqueId] = AgentInfo(id: uniqueId, position: (x: 5, y: 5), color: .red)
    
    return (world, uniqueId)
}

// Helper to reset all mock state in one place
func resetAllMockState(
    connection: MockConnection? = nil,
    listener: MockListener? = nil,
    factory: MockNetworkFactory? = nil,
    delegate: MockServerConnectionManagerDelegate? = nil
) {
    connection?.reset()
    listener?.reset()
    factory?.reset()
    delegate?.reset()
}