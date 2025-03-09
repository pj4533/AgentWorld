import Foundation
import OSLog

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
        let requestData = try jsonEncoder.encode(requestBody)
        
        // Create URL request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestData
        
        // Send the request
        logger.debug("📤 Sending request to OpenAI API")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ Invalid response from OpenAI API")
            throw NSError(domain: "OpenAIService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response from OpenAI API"
            ])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ HTTP error \(httpResponse.statusCode): \(errorMessage)")
            throw NSError(domain: "OpenAIService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode): \(errorMessage)"
            ])
        }
        
        // Parse the response
        let jsonDecoder = JSONDecoder()
        let apiResponse = try jsonDecoder.decode(ChatCompletionResponse.self, from: data)
        
        guard let choice = apiResponse.choices.first else {
            logger.error("❌ No choices in OpenAI API response")
            throw NSError(domain: "OpenAIService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "No choices in OpenAI API response"
            ])
        }
        
        logger.debug("✅ Received response from OpenAI API")
        return choice.message.content
    }
    
    // MARK: - Decision Making
    func decideNextAction(observation: ServerResponse) async throws -> AgentAction {
        logger.info("🧠 Deciding next action based on observation at time step \(observation.timeStep)")
        
        let systemPrompt = "You are an explorer in a new world. Try to see as much of the world as you can, without revisiting areas you have already visited."
        
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
        
        // Get a response from the OpenAI API
        let jsonResponse = try await chatCompletion(systemPrompt: systemPrompt, userPrompt: userPrompt)
        logger.debug("📄 OpenAI response: \(jsonResponse)")
        
        // Parse the JSON response
        let responseData = jsonResponse.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            let gptAction = try decoder.decode(GPTActionResponse.self, from: responseData)
            
            // Convert to AgentAction
            return AgentAction(
                action: .move,
                targetTile: gptAction.targetTile,
                message: nil
            )
        } catch {
            logger.error("❌ Failed to decode OpenAI response: \(error.localizedDescription)")
            logger.error("📄 Raw response: \(jsonResponse)")
            
            // Fallback to a simple action (stay in place)
            return AgentAction(
                action: .move,
                targetTile: Coordinate(x: observation.currentLocation.x, y: observation.currentLocation.y),
                message: nil
            )
        }
    }
}