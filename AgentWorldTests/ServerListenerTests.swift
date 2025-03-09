//
//  ServerListenerTests.swift
//  AgentWorldTests
//
//  Created by Claude on 3/9/25.
//

import Foundation
import Testing
import Network
@testable import AgentWorld

@Suite
struct ServerListenerTests {
    // Helper method to create unique port numbers for each test
    func createUniquePort() -> UInt16 {
        // Create a deterministic unique port using a UUID to avoid port conflicts
        let uuid = UUID().uuidString
        let portSeed = uuid.utf8.reduce(0) { $0 + UInt16($1) }
        return UInt16(50000 + (portSeed % 10000)) // Range 50000-60000
    }
    
    // Helper to create isolated test dependencies
    func createTestDependencies() -> (MockNetworkFactory, ServerConnectionManager, UInt16) {
        let mockFactory = MockNetworkFactory()
        // Reset state to ensure clean test isolation
        mockFactory.reset()
        
        let world = World()
        // Create a test-specific world with a unique identifier
        let testId = UUID().uuidString
        
        // Use a unique port for the manager to avoid port conflicts
        let managerPort = createUniquePort()
        let manager = ServerConnectionManager(port: managerPort, world: world, factory: mockFactory)
        
        // Use a different unique port for the listener
        let listenerPort = createUniquePort()
        
        return (mockFactory, manager, listenerPort)
    }
    
    // MARK: - Tests
    @Test
    func testInitializationSetsPort() {
        // Setup with isolated dependencies
        let (mockFactory, manager, testPort) = createTestDependencies()
        
        // Act
        let listener = ServerListener(factory: mockFactory, manager: manager)
        do {
            try listener.start(port: testPort)
        } catch {
            #expect(false, "Start should not throw an error: \(error)")
        }
        
        // Assert - check the port was set on the created listener
        #expect(mockFactory.lastCreatedListener?.port?.rawValue == testPort)
    }
    
    @Test
    func testStartCallsStateHandler() {
        // Setup with isolated dependencies
        let (mockFactory, manager, testPort) = createTestDependencies()
        
        // Instead of relying on callbacks, we'll use a direct synchronous approach
        // Create a custom listener that tracks when its state handler is set
        class StateTrackingMockListener: MockListener {
            var stateHandlerWasSet = false
            
            override var stateUpdateHandler: ((NWListener.State) -> Void)? {
                didSet {
                    if stateUpdateHandler != nil {
                        stateHandlerWasSet = true
                    }
                }
            }
        }
        
        // Create a listener to use for this test
        let trackingListener = StateTrackingMockListener(port: testPort)
        
        // Replace the factory's createListener method to return our tracking listener
        mockFactory.createListenerImpl = { _, _ in
            return trackingListener
        }
        
        // Create server listener and start it
        let serverListener = ServerListener(factory: mockFactory, manager: manager)
        
        do {
            try serverListener.start(port: testPort)
        } catch {
            #expect(false, "Start should not throw an error: \(error)")
        }
        
        // Assert - by this point the state handler should have been set
        #expect(trackingListener.stateHandlerWasSet, "State update handler should have been set")
    }
    
    @Test
    func testStartThrowsErrorForInvalidPort() {
        // Setup with isolated dependencies
        let (mockFactory, manager, _) = createTestDependencies()
        
        // Configure the factory to fail
        mockFactory.shouldFailListenerCreation = true
        
        let listener = ServerListener(factory: mockFactory, manager: manager)
        
        // Act & Assert
        do {
            // Use port 0 which is invalid (or use any other port since the factory is configured to fail)
            try listener.start(port: 0)
            #expect(false, "Expected an error to be thrown")
        } catch {
            // Verify error was thrown with correct domain
            if let nsError = error as NSError? {
                #expect(nsError.domain == "MockNetworkFactory")
            } else {
                #expect(false, "Expected NSError but got a different error type")
            }
        }
    }
    
    @Test
    func testStopCallsCancel() {
        // Setup with isolated dependencies
        let (mockFactory, manager, testPort) = createTestDependencies()
        
        // Use a simpler, more direct approach without relying on async callbacks
        class CancelTrackingMockListener: MockListener {
            var wasCanceled = false
            
            override func cancel() {
                wasCanceled = true 
                super.cancel()
            }
        }
        
        // Create our test listener
        let trackingListener = CancelTrackingMockListener(port: testPort)
        
        // Configure the factory to return our test listener
        mockFactory.createListenerImpl = { _, _ in
            return trackingListener
        }
        
        // Create and start the server listener
        let serverListener = ServerListener(factory: mockFactory, manager: manager)
        
        do {
            try serverListener.start(port: testPort)
        } catch {
            #expect(false, "Start should not throw an error: \(error)")
        }
        
        // Act - stop the server
        serverListener.stop()
        
        // Assert - check if cancel was called
        #expect(trackingListener.wasCanceled, "The listener's cancel method should be called")
    }
}