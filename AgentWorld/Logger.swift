//
//  Logger.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import OSLog

/// A centralized logging system for AgentWorld
struct AppLogger {
    private let logger: Logger
    
    init(category: String) {
        self.logger = Logger(subsystem: "com.agentworld.AgentWorld", category: category)
    }
    
    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
    
    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
    
    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}