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
                
                do {
                    // Try to parse the data as ServerResponse
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(ServerResponse.self, from: data)
                    
                    // Process the server response
                    print("📩 Received observation at time step \(response.timeStep)")
                    print("🧭 Current location: (\(response.currentLocation.x), \(response.currentLocation.y)) - \(response.currentLocation.type)")
                    print("👀 Surroundings: \(response.surroundings.tiles.count) tiles and \(response.surroundings.agents.count) agents visible")
                    
                    logger.debug("📨 Received response: \(response.responseType) for agent \(response.agent_id)")
                    
                    // Implement simple agent decision logic
                    let action = createAction(basedOn: response)
                    try await networkService.sendAction(action)
                    print("🚀 Sent action: \(action.action.rawValue)")
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
    
    private func createAction(basedOn response: ServerResponse) -> AgentAction {
        // Simple random movement strategy
        let random = Int.random(in: 0...10)
        
        // 20% chance to speak
        if random < 2 {
            return AgentAction(
                action: .speak,
                targetTile: nil,
                message: "Hello from agent \(response.agent_id)!"
            )
        }
        // 20% chance to stay put
        else if random < 4 {
            return AgentAction(
                action: .wait,
                targetTile: nil,
                message: nil
            )
        } 
        // 60% chance to move randomly
        else {
            // Get current position
            let currentX = response.currentLocation.x
            let currentY = response.currentLocation.y
            
            // Find neighboring tiles that aren't water
            let walkableTiles = response.surroundings.tiles.filter { tile in
                // Must be adjacent (including diagonals)
                let distance = abs(tile.x - currentX) + abs(tile.y - currentY)
                let isDiagonal = abs(tile.x - currentX) == 1 && abs(tile.y - currentY) == 1
                let isAdjacent = (distance <= 2 && !isDiagonal) || (isDiagonal && distance == 2)
                
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
                // If no walkable tiles, wait
                return AgentAction(
                    action: .wait,
                    targetTile: nil,
                    message: nil
                )
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