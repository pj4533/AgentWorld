//
//  ServerConnectionManagerTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/8/25.
//

import Foundation
import Testing
import Network
import XCTest
@testable import AgentWorld

@Suite
struct ServerConnectionManagerTests {
    
    // MARK: - Test Properties
    
    // MARK: - Tests
    @Test
    func testInitialization() {
        // Create with mock factory to avoid real network connections
        let world = World()
        let mockFactory = MockNetworkFactory()
        let serverManager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        
        // Verify the server initializes with empty agents in the world
        #expect(serverManager.world.agents.isEmpty)
    }
    
    @Test
    func testServerStopsCleanly() {
        // Create with mock factory to avoid real network connections
        let world = World()
        let mockFactory = MockNetworkFactory()
        let serverManager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        
        // Just test that stopServer doesn't crash
        serverManager.stopServer()
        #expect(true)
    }
}