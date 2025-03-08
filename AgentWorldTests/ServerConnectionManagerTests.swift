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
        serverManager = ServerConnectionManager(port: 8000)
    }
    
    // MARK: - Tests
    @Test
    func testInitialization() {
        // Verify the server initializes with empty agent positions
        #expect(serverManager.agentPositions.isEmpty)
    }
    
    @Test
    func testServerStopsCleanly() {
        // Just test that stopServer doesn't crash
        serverManager.stopServer()
        #expect(true)
    }
}