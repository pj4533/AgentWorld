import Foundation
import ArgumentParser
import OSLog

// MARK: - Logger setup
fileprivate let logger = Logger(subsystem: "com.agentworld.agent", category: "Agent")

// MARK: - Agent Command
struct AgentCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "A client agent for AgentWorld 🌎",
        version: "1.0.0"
    )
    
    // MARK: - Command Arguments
    @Option(name: .long, help: "The host to connect to 🖥️")
    var host: String = "localhost"
    
    @Option(name: .long, help: "The port to connect to 🔌")
    var port: UInt16 = 8000
    
    // MARK: - Command execution
    func run() throws {
        logger.info("🚀 Agent starting up!")
        logger.info("🔌 Connecting to \(self.host):\(self.port)")
        
        // Just print hello for now
        print("Hello from agent 🤖")
        print("Will connect to \(host):\(port) in future versions ⏳")
        
        logger.info("👋 Agent shutting down")
    }
}

// MARK: - Main entry point
@main
struct AgentMain {
    static func main() {
        logger.info("📱 Agent program starting")
        AgentCommand.main()
    }
}