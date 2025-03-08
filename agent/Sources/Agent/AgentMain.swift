import Foundation
import ArgumentParser
import OSLog

// MARK: - Logger setup
fileprivate let logger = Logger(subsystem: "com.agentworld.agent", category: "Agent")

// MARK: - Agent Command
struct AgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
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
    func run() async throws {
        logger.info("🚀 Agent starting up!")
        logger.info("🔌 Connecting to \(self.host):\(self.port)")
        
        print("Connecting to \(host):\(port)...")
        
        // Create network service and establish connection
        let networkService = NetworkService(host: host, port: port)
        
        do {
            // Connect to the server
            try await networkService.connect()
            print("Connected to server! 🎉")
            
            // Keep receiving data in a loop
            try await receiveDataLoop(using: networkService)
        } catch {
            logger.error("❌ Connection error: \(error.localizedDescription)")
            print("Failed to connect: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func receiveDataLoop(using networkService: NetworkService) async throws {
        print("Listening for server messages... 👂")
        
        // Start an infinite loop to receive data
        while true {
            do {
                let data = try await networkService.receiveData()
                
                // Try to parse as string
                if let message = String(data: data, encoding: .utf8) {
                    print("📩 Received: \(message)")
                    logger.debug("📨 Received message: \(message)")
                } else {
                    // For binary data, show size and first few bytes
                    let preview = data.prefix(min(10, data.count))
                        .map { String(format: "%02x", $0) }
                        .joined(separator: " ")
                    
                    print("📦 Received \(data.count) bytes: \(preview)...")
                    logger.debug("📦 Received binary data: \(data.count) bytes")
                }
            } catch {
                logger.error("📡 Data reception error: \(error.localizedDescription)")
                print("❌ Connection error: \(error.localizedDescription)")
                throw error
            }
        }
    }
}

// MARK: - Main entry point
@main
struct AgentMain {
    static func main() async {
        logger.info("📱 Agent program starting")
        await AgentCommand.main()
    }
}