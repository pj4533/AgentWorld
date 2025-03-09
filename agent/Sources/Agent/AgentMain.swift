import Foundation
import ArgumentParser
import OSLog

// MARK: - Logger setup
fileprivate let subsystemIdentifier = "com.agentworld.agent"
fileprivate let logger = Logger(subsystem: subsystemIdentifier, category: "Agent")

// Console logger for development - much simpler approach
fileprivate func logToConsole(_ type: String, _ message: String) {
    if ProcessInfo.processInfo.environment["AGENT_LOG_CONSOLE"] == "1" || 
       ProcessInfo.processInfo.arguments.contains("--debug-logging") {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\(type)] \(message)")
    }
}

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
    
    @Option(name: .long, help: "Path to .env file 📄")
    var envFile: String = ".env"
    
    @Flag(name: .long, help: "Use random movement instead of LLM 🎲")
    var randomMovement: Bool = false
    
    @Flag(name: .long, help: "Enable console logging for debugging 🐞")
    var debugLogging: Bool = false
    
    @Flag(name: .long, help: "Enable detailed OpenAI API logging 🧠")
    var llmLogging: Bool = false
    
    // MARK: - Command execution
    func run() async throws {
        // Set environment variable for console logging if flag is enabled
        if debugLogging {
            setenv("AGENT_LOG_CONSOLE", "1", 1)
            print("Debug logging enabled to console 🐞")
        }
        
        // Set environment variable for LLM logging
        if llmLogging {
            setenv("AGENT_LLM_LOGGING", "1", 1)
            print("Detailed LLM logging enabled 🧠")
            
            // When LLM logging is enabled, also enable console logging
            if !debugLogging {
                setenv("AGENT_LOG_CONSOLE", "1", 1)
            }
        }
        
        logger.info("🚀 Agent starting up!")
        logToConsole("INFO", "🚀 Agent starting up!")
        
        // Load environment variables from .env file
        EnvironmentService.loadEnvironment(from: envFile)
        
        // Initialize OpenAI service if we're using LLM-based decisions
        let openAIService: OpenAIService?
        
        if !randomMovement {
            // Get OpenAI API key from environment
            guard let apiKey = EnvironmentService.getEnvironmentVariable("OPENAI_API_KEY") else {
                logger.error("❌ OPENAI_API_KEY not found in environment or .env file")
                print("Error: OPENAI_API_KEY environment variable is required")
                print("Please add it to your .env file or set it in your environment")
                throw NSError(domain: "AgentCommand", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "OPENAI_API_KEY not found"
                ])
            }
            
            // Initialize OpenAI service
            openAIService = OpenAIService(apiKey: apiKey)
            logger.info("🧠 LLM-based decision making enabled")
            print("LLM-based decision making enabled 🧠")
        } else {
            openAIService = nil
            logger.info("🎲 Random movement enabled")
            print("Random movement enabled 🎲")
        }
        
        logger.info("🔌 Connecting to \(self.host):\(self.port)")
        print("Connecting to \(host):\(port)...")
        
        // Create network service and establish connection
        let networkService = NetworkService(host: host, port: port)
        
        do {
            // Connect to the server
            try await networkService.connect()
            print("Connected to server! 🎉")
            
            // Keep receiving data in a loop
            try await receiveDataLoop(using: networkService, openAIService: openAIService)
        } catch {
            logger.error("❌ Connection error: \(error.localizedDescription)")
            print("Failed to connect: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func receiveDataLoop(using networkService: NetworkService, openAIService: OpenAIService?) async throws {
        print("Listening for server messages... 👂")
        
        // Start an infinite loop to receive data
        while true {
            do {
                let data = try await networkService.receiveData()
                
                do {
                    // Try to parse the data as ServerResponse
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(ServerResponse.self, from: data)
                    
                    // Process the server response
                    print("📩 Received observation at time step \(response.timeStep)")
                    print("🧭 Current location: (\(response.currentLocation.x), \(response.currentLocation.y)) - \(response.currentLocation.type)")
                    print("👀 Surroundings: \(response.surroundings.tiles.count) tiles and \(response.surroundings.agents.count) agents visible")
                    
                    logger.debug("📨 Received response: \(response.responseType) for agent \(response.agent_id)")
                    logToConsole("DEBUG", "📨 Received response: \(response.responseType) for agent \(response.agent_id)")
                    
                    // Only send an action if this is an observation message
                    if response.responseType == "observation" {
                        // Decide on the next action
                        let action: AgentAction
                        
                        if randomMovement || openAIService == nil {
                            // Use simple random movement logic
                            action = createRandomAction(basedOn: response)
                        } else {
                            // Use LLM for decision making
                            do {
                                action = try await decideNextAction(basedOn: response, using: openAIService)
                            } catch {
                                logger.error("❌ LLM decision error: \(error.localizedDescription), falling back to random")
                                logToConsole("ERROR", "❌ LLM decision error: \(error.localizedDescription), falling back to random")
                                action = createRandomAction(basedOn: response)
                            }
                        }
                        
                        // Send the action to the server
                        try await networkService.sendAction(action)
                        print("🚀 Sent action: \(action.action.rawValue) to \(action.targetTile?.x ?? 0), \(action.targetTile?.y ?? 0)")
                    } else {
                        print("📝 Received \(response.responseType) message, not sending an action")
                    }
                } catch {
                    // If parsing fails, show the raw data
                    if let message = String(data: data, encoding: .utf8) {
                        print("📩 Received (unparsed): \(message)")
                        logger.debug("📨 Received unparsed message: \(message)")
                    } else {
                        // For binary data, show size and first few bytes
                        let preview = data.prefix(min(10, data.count))
                            .map { String(format: "%02x", $0) }
                            .joined(separator: " ")
                        
                        print("📦 Received \(data.count) bytes: \(preview)...")
                        logger.debug("📦 Received binary data: \(data.count) bytes")
                    }
                    
                    logger.error("🔄 JSON parsing error: \(error.localizedDescription)")
                }
            } catch {
                logger.error("📡 Data reception error: \(error.localizedDescription)")
                print("❌ Connection error: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    // MARK: - Agent Decision Logic
    
    // LLM-based decision making
    private func decideNextAction(basedOn response: ServerResponse, using openAIService: OpenAIService?) async throws -> AgentAction {
        logger.info("🤖 Using LLM to decide next action at time step \(response.timeStep)")
        
        guard let openAIService = openAIService else {
            throw NSError(domain: "AgentCommand", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI service not initialized"
            ])
        }
        
        print("Asking AI for next move... 🧠")
        let action = try await openAIService.decideNextAction(observation: response)
        
        // Verify that the target tile is valid (adjacent and not water)
        if let targetTile = action.targetTile {
            let currentX = response.currentLocation.x
            let currentY = response.currentLocation.y
            let dx = abs(targetTile.x - currentX)
            let dy = abs(targetTile.y - currentY)
            
            // If not adjacent or if water, fall back to random
            let isAdjacent = (dx == 1 && dy == 0) || (dx == 0 && dy == 1) || (dx == 0 && dy == 0)
            
            // Find if the target is water
            let targetTileInfo = response.surroundings.tiles.first { 
                $0.x == targetTile.x && $0.y == targetTile.y 
            }
            let isWater = targetTileInfo?.type == .water
            
            if !isAdjacent || isWater {
                logger.warning("⚠️ LLM suggested invalid move to (\(targetTile.x), \(targetTile.y)), using fallback")
                logToConsole("WARNING", "⚠️ LLM suggested invalid move to (\(targetTile.x), \(targetTile.y)), using fallback")
                return createRandomAction(basedOn: response)
            }
        }
        
        return action
    }
    
    // Random action for fallback
    private func createRandomAction(basedOn response: ServerResponse) -> AgentAction {
        // Get current position
        let currentX = response.currentLocation.x
        let currentY = response.currentLocation.y
        
        // Find immediately adjacent tiles that aren't water (no diagonals)
        let walkableTiles = response.surroundings.tiles.filter { tile in
            // Calculate Manhattan distance to check adjacency (only direct neighbors)
            let dx = abs(tile.x - currentX)
            let dy = abs(tile.y - currentY)
            
            // Only one step in one direction (up, down, left, right)
            let isAdjacent = (dx == 1 && dy == 0) || (dx == 0 && dy == 1)
            
            // Must not be water
            let isWalkable = tile.type != .water
            
            return isAdjacent && isWalkable
        }
        
        // Choose a random walkable tile
        if let targetTile = walkableTiles.randomElement() {
            return AgentAction(
                action: .move,
                targetTile: Coordinate(x: targetTile.x, y: targetTile.y),
                message: nil
            )
        } else {
            // If no walkable tiles, stay in place but using move action
            return AgentAction(
                action: .move,
                targetTile: Coordinate(x: currentX, y: currentY),
                message: nil
            )
        }
    }
}

// MARK: - Main entry point
@main
struct AgentMain {
    static func main() async {
        // Check for debug logging flag
        if ProcessInfo.processInfo.environment["AGENT_LOG_CONSOLE"] == "1" ||
           ProcessInfo.processInfo.arguments.contains("--debug-logging") {
            print("Debug logging enabled to console")
        }
        
        logger.info("📱 Agent program starting")
        logToConsole("INFO", "📱 Agent program starting")
        await AgentCommand.main()
    }
}