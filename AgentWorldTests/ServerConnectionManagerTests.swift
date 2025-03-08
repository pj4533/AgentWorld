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
    let serverManager: ServerConnectionManager
    
    // MARK: - Setup & Teardown
    init() {
        let world = World()
        serverManager = ServerConnectionManager(port: 8000, world: world)
    }
    
    // MARK: - Tests
    @Test
    func testInitialization() {
        // Verify the server initializes with empty agents in the world
        #expect(serverManager.world.agents.isEmpty)
    }
    
    @Test
    func testServerStopsCleanly() {
        // Just test that stopServer doesn't crash
        serverManager.stopServer()
        #expect(true)
    }
}