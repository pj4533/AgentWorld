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
    // We don't need the ServerConnectionManager at the app level anymore,
    // as it's created in the WorldScene based on the world in SimulationViewModel
    private let logger = AppLogger(category: "AgentWorldApp")
    
    init() {
        logger.info("AgentWorld application starting")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 640, minHeight: 700)
                .onDisappear {
                    // Log when app closes
                    logger.info("AgentWorld application closing")
                }
        }
        .windowResizability(.contentSize)
    }
}
