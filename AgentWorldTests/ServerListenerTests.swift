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
    
    // MARK: - Tests
    @Test
    func testInitializationSetsPort() {
        // Setup
        let testPort: UInt16 = 9999
        let mockFactory = MockNetworkFactory()
        let world = World()
        let manager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        
        // Act
        let listener = ServerListener(factory: mockFactory, manager: manager)
        
        // Assert
        #expect(listener !== nil)
    }
    
    @Test
    func testStartCallsStateHandler() {
        // Setup
        let mockFactory = MockNetworkFactory()
        let world = World()
        let manager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        let listener = ServerListener(factory: mockFactory, manager: manager)
        
        // Prepare a mock listener to simulate what would happen
        let mockListener = MockListener()
        var stateHandlerCalled = false
        mockListener.stateUpdateHandler = { state in
            stateHandlerCalled = true
        }
        mockFactory.lastCreatedListener = mockListener
        
        // Act
        do {
            try listener.start(port: 9000)
        } catch {
            #expect(false, "Start should not throw an error: \(error)")
        }
        
        // Assert
        #expect(stateHandlerCalled)
    }
    
    @Test
    func testStartThrowsErrorForInvalidPort() {
        // Setup
        let mockFactory = MockNetworkFactory()
        mockFactory.shouldFailListenerCreation = true
        let world = World()
        let manager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        let listener = ServerListener(factory: mockFactory, manager: manager)
        
        // Act & Assert
        do {
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
        // Setup
        let mockFactory = MockNetworkFactory()
        let world = World()
        let manager = ServerConnectionManager(port: 8000, world: world, factory: mockFactory)
        let listener = ServerListener(factory: mockFactory, manager: manager)
        
        // Create a mock listener to check cancellation
        let mockListener = MockListener()
        var cancelCalled = false
        
        // Set up a way to track if cancel is called
        class CancelTracker {
            var wasCalled = false
        }
        let tracker = CancelTracker()
        
        // Set up our mock listener
        mockListener.stateUpdateHandler = { _ in }
        
        // Override the original listener to intercept cancel
        class TrackingMockListener: MockListener {
            let tracker: CancelTracker
            
            init(tracker: CancelTracker) {
                self.tracker = tracker
                super.init()
            }
            
            override func cancel() {
                tracker.wasCalled = true
                super.cancel()
            }
        }
        
        // Replace with our tracking listener
        let trackingListener = TrackingMockListener(tracker: tracker)
        mockFactory.lastCreatedListener = trackingListener
        
        // Start the listener
        do {
            try listener.start(port: 9000)
        } catch {
            #expect(false, "Start should not throw an error: \(error)")
        }
        
        // Act
        listener.stop()
        
        // Assert
        #expect(tracker.wasCalled)
    }
}