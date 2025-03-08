//
//  AgentWorldApp.swift
//  AgentWorld
//
//  Created by PJ Gray on 3/8/25.
//

import SwiftUI
import OSLog

@main
struct AgentWorldApp: App {
    // Create the server connection manager as a StateObject
    @StateObject private var serverConnectionManager = ServerConnectionManager()
    private let logger = AppLogger(category: "AgentWorldApp")
    
    init() {
        logger.info("AgentWorld application starting")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 640, minHeight: 700)
                .environmentObject(serverConnectionManager)
                .onDisappear {
                    // Stop the server when the app closes
                    serverConnectionManager.stopServer()
                    logger.info("AgentWorld application closing")
                }
        }
        .windowResizability(.contentSize)
    }
}
