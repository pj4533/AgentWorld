import Foundation
import OSLog

// For tracking OpenAI API interaction details
fileprivate func logOpenAI(_ type: String, _ message: String) {
    let isLLMLoggingEnabled = ProcessInfo.processInfo.environment["AGENT_LLM_LOGGING"] == "1" ||
                             ProcessInfo.processInfo.arguments.contains("--llm-logging")
    
    // For large messages, only log them if LLM logging is specifically enabled
    if !isLLMLoggingEnabled && (
        type == "SYSTEM_PROMPT" || 
        type == "USER_PROMPT" || 
        type == "REQUEST" || 
        type == "RAW_RESPONSE" ||
        message.count > 1000) {
        // Skip detailed logs unless LLM logging is enabled
        return
    }
    
    // Always log OpenAI interactions to a file for later analysis
    let fileManager = FileManager.default
    let logDirectory = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/AgentWorld")
    
    // Create directory if it doesn't exist
    if !fileManager.fileExists(atPath: logDirectory.path) {
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }
    
    // Create a unique log file for each run by using the startup timestamp
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let startupTime = dateFormatter.string(from: Date())
    
    let logFile = logDirectory.appendingPathComponent("openai_\(startupTime).log")
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logEntry = "[\(timestamp)] [\(type)] \(message)\n"
    
    // Append to log file or create a new one
    if fileManager.fileExists(atPath: logFile.path) {
        if let fileHandle = FileHandle(forWritingAtPath: logFile.path) {
            fileHandle.seekToEndOfFile()
            if let data = logEntry.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        }
    } else {
        try? logEntry.write(to: logFile, atomically: true, encoding: .utf8)
    }
    
    // Check if console logging is enabled
    let isConsoleLoggingEnabled = ProcessInfo.processInfo.environment["AGENT_LOG_CONSOLE"] == "1" || 
                                 ProcessInfo.processInfo.arguments.contains("--debug-logging")
    
    // Also print to console if debug logging is enabled
    if isConsoleLoggingEnabled {
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let shortTimestamp = dateFormatter.string(from: Date())
        
        // For very long messages, truncate them for console output
        var displayMessage = message
        if displayMessage.count > 1000 && !isLLMLoggingEnabled {
            displayMessage = String(displayMessage.prefix(1000)) + "... [truncated, use --llm-logging to see full content]"
        }
        
        print("[\(shortTimestamp)] [OPENAI] \(displayMessage)")
    }
}

// MARK: - OpenAI Models

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let response_format: ResponseFormat?
    
    struct ResponseFormat: Codable {
        let type: String
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let index: Int
        let message: ChatMessage
        let finish_reason: String
    }
}

struct GPTActionResponse: Codable {
    let action: String
    let targetTile: Coordinate
}

// MARK: - OpenAI Service

actor OpenAIService {
    // MARK: - Properties
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let logger = Logger(subsystem: "com.agentworld.agent", category: "OpenAIService")
    
    // MARK: - Initialization
    init(apiKey: String) {
        self.apiKey = apiKey
        self.logger.debug("🧠 OpenAI service initialized")
    }
    
    // MARK: - Chat Completion
    func chatCompletion(systemPrompt: String, userPrompt: String) async throws -> String {
        logger.debug("🤖 Sending chat completion request to OpenAI")
        
        // Log the prompts
        logOpenAI("SYSTEM_PROMPT", systemPrompt)
        logOpenAI("USER_PROMPT", userPrompt)
        
        // Create the request
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userPrompt)
        ]
        
        let requestBody = ChatCompletionRequest(
            model: "gpt-4o",
            messages: messages,
            response_format: ChatCompletionRequest.ResponseFormat(type: "json_object")
        )
        
        // Encode the request
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted]
        let requestData = try jsonEncoder.encode(requestBody)
        
        // Log the request payload
        if let requestStr = String(data: requestData, encoding: .utf8) {
            logOpenAI("REQUEST", requestStr)
        }
        
        // Create URL request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestData
        
        // Send the request
        let requestStartTime = Date()
        logger.debug("📤 Sending request to OpenAI API")
        let (data, response) = try await URLSession.shared.data(for: request)
        let requestDuration = Date().timeIntervalSince(requestStartTime)
        
        logOpenAI("REQUEST_TIME", "Request took \(String(format: "%.2f", requestDuration)) seconds")
        
        // Log raw response data
        if let responseStr = String(data: data, encoding: .utf8) {
            logOpenAI("RAW_RESPONSE", responseStr)
        }
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            let errorMsg = "Invalid response from OpenAI API"
            logger.error("❌ \(errorMsg)")
            logOpenAI("ERROR", errorMsg)
            throw NSError(domain: "OpenAIService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: errorMsg
            ])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            let errorMsg = "HTTP error \(httpResponse.statusCode): \(errorMessage)"
            logger.error("❌ \(errorMsg)")
            logOpenAI("ERROR", errorMsg)
            throw NSError(domain: "OpenAIService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: errorMsg
            ])
        }
        
        // Parse the response
        let jsonDecoder = JSONDecoder()
        let apiResponse = try jsonDecoder.decode(ChatCompletionResponse.self, from: data)
        
        guard let choice = apiResponse.choices.first else {
            let errorMsg = "No choices in OpenAI API response"
            logger.error("❌ \(errorMsg)")
            logOpenAI("ERROR", errorMsg)
            throw NSError(domain: "OpenAIService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: errorMsg
            ])
        }
        
        // Log the model's response
        logOpenAI("RESPONSE_CONTENT", choice.message.content)
        logOpenAI("FINISH_REASON", choice.finish_reason)
        
        logger.debug("✅ Received response from OpenAI API")
        return choice.message.content
    }
    
    // MARK: - Decision Making
    func decideNextAction(observation: ServerResponse) async throws -> AgentAction {
        logger.info("🧠 Deciding next action based on observation at time step \(observation.timeStep)")
        logOpenAI("DECISION", "Starting decision process for time step \(observation.timeStep)")
        
        // Log the current agent position
        logOpenAI("AGENT_POS", "Current position: (\(observation.currentLocation.x), \(observation.currentLocation.y)) - \(observation.currentLocation.type)")
        
        // Log overview of surroundings
        logOpenAI("SURROUNDINGS", "Visible tiles: \(observation.surroundings.tiles.count), Visible agents: \(observation.surroundings.agents.count)")
        
        let systemPrompt = """
        You are an explorer in a new world. 
        Try to see as much of the world as you can, without revisiting areas you have already visited.

        You cannot pass through water or mountains, but you can move one tile in any direction.
        """
        
        // Create a user prompt with the current observation
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let observationData = try encoder.encode(observation)
        let observationString = String(data: observationData, encoding: .utf8) ?? "Unable to encode observation"
        
        let userPrompt = """
        Decide where to move next.
        
        Output your next move using JSON formatted like this:
        {"action": "move", "targetTile": {"x": 1, "y": 2}}
        
        Current Observation:
        \(observationString)
        """
        
        // Mark the start of LLM decision making 
        let decisionStartTime = Date()
        logOpenAI("DECISION_START", "Starting LLM request for movement decision")
        
        // Get a response from the OpenAI API
        let jsonResponse = try await chatCompletion(systemPrompt: systemPrompt, userPrompt: userPrompt)
        
        // Log timing information
        let decisionDuration = Date().timeIntervalSince(decisionStartTime)
        logOpenAI("DECISION_TIME", "Decision process took \(String(format: "%.2f", decisionDuration)) seconds")
        
        logger.debug("📄 OpenAI response: \(jsonResponse)")
        
        // Parse the JSON response
        let responseData = jsonResponse.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            let gptAction = try decoder.decode(GPTActionResponse.self, from: responseData)
            
            // Log the decision that was made
            logOpenAI("ACTION_DECISION", "Moving to position: (\(gptAction.targetTile.x), \(gptAction.targetTile.y))")
            
            // Convert to AgentAction
            return AgentAction(
                action: .move,
                targetTile: gptAction.targetTile,
                message: nil
            )
        } catch {
            // Log parsing error
            logger.error("❌ Failed to decode OpenAI response: \(error.localizedDescription)")
            logger.error("📄 Raw response: \(jsonResponse)")
            logOpenAI("PARSE_ERROR", "Failed to parse LLM response: \(error.localizedDescription)")
            logOpenAI("INVALID_JSON", jsonResponse)
            
            // Log fallback action
            logOpenAI("FALLBACK", "Using fallback action: staying in place at (\(observation.currentLocation.x), \(observation.currentLocation.y))")
            
            // Fallback to a simple action (stay in place)
            return AgentAction(
                action: .move,
                targetTile: Coordinate(x: observation.currentLocation.x, y: observation.currentLocation.y),
                message: nil
            )
        }
    }
}