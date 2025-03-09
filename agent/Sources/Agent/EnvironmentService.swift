import Foundation
import OSLog

struct EnvironmentService {
    private static let logger = Logger(subsystem: "com.agentworld.agent", category: "EnvironmentService")
    
    // Process an .env file at the given path and load variables
    static func loadEnvironment(from path: String = ".env") {
        do {
            logger.debug("📁 Loading environment variables from \(path)")
            
            // Read the .env file
            let fileURL = URL(fileURLWithPath: path)
            let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
            
            // Process each line
            fileContents.split(separator: "\n").forEach { line in
                // Skip comments and empty lines
                let trimmedLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    return
                }
                
                // Parse KEY=VALUE pairs
                let parts = trimmedLine.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else {
                    logger.warning("⚠️ Invalid line in .env file: \(trimmedLine)")
                    return
                }
                
                let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                var value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove quotes if present
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                
                // Set the environment variable
                setenv(key, value, 1)
                logger.debug("🔑 Set environment variable: \(key)")
            }
            
            logger.info("✅ Environment loaded successfully from \(path)")
        } catch {
            logger.warning("⚠️ Failed to load .env file: \(error.localizedDescription)")
            logger.info("ℹ️ Will use existing environment variables instead")
        }
    }
    
    // Get a value from environment
    static func getEnvironmentVariable(_ name: String) -> String? {
        guard let rawValue = getenv(name) else {
            return nil
        }
        return String(cString: rawValue)
    }
}