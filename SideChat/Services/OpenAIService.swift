import Foundation
import Defaults

// MARK: - OpenAI Service

/// Implementation of LLMServiceProtocol for OpenAI's GPT models
/// Supports streaming responses using Server-Sent Events (SSE)
@MainActor
class OpenAIService: LLMServiceProtocol {
    
    // MARK: - Properties
    
    let provider: LLMProvider = .openai
    private let configuration: ProviderConfiguration
    
    nonisolated var isConfigured: Bool {
        return KeychainManager.hasAPIKey(for: .openai)
    }
    
    private var baseURL: String {
        // Use custom base URL if provided, otherwise use default
        return configuration.baseURL.isEmpty ? "https://api.openai.com/v1" : configuration.baseURL
    }
    
    private let session: URLSession
    
    // MARK: - Initialization
    
    init(configuration: ProviderConfiguration) {
        self.configuration = configuration
        
        // Configure URLSession with extended timeout for streaming
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = Defaults[.requestTimeout]
        sessionConfig.timeoutIntervalForResource = Defaults[.requestTimeout]
        self.session = URLSession(configuration: sessionConfig)
    }
    
    // MARK: - LLMServiceProtocol Implementation
    
    func sendMessage(
        content: String,
        images: [Data],
        chatHistory: [Message]
    ) async throws -> AsyncThrowingStream<String, Error> {
        print("[OpenAI] Starting sendMessage with content: \(content.prefix(50))...")
        
        // Check configuration
        guard isConfigured else {
            print("[OpenAI] Service not configured")
            throw LLMServiceError.notConfigured
        }
        
        guard let apiKey = KeychainManager.getAPIKey(for: .openai) else {
            print("[OpenAI] No API key found")
            throw LLMServiceError.invalidAPIKey
        }
        
        print("[OpenAI] API key found, building request...")
        
        // Build the request
        let request = try buildRequest(
            content: content,
            images: images,
            chatHistory: chatHistory,
            apiKey: apiKey
        )
        
        print("[OpenAI] Request built successfully")
        
        // Create the streaming response
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    // Check response status
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMServiceError.invalidResponse
                    }
                    
                    print("[OpenAI] Response status code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode != 200 {
                        // Collect error response data
                        var errorBytes: [UInt8] = []
                        for try await byte in bytes {
                            errorBytes.append(byte)
                        }
                        let errorData = Data(errorBytes)
                        if let errorString = String(data: errorData, encoding: .utf8) {
                            print("[OpenAI] Error response: \(errorString)")
                        }
                        try await handleErrorResponse(statusCode: httpResponse.statusCode, data: errorData)
                        return
                    }
                    
                    print("[OpenAI] Starting to process SSE stream...")
                    
                    // Process the SSE stream
                    var buffer = ""
                    var messageCount = 0
                    
                    for try await byte in bytes {
                        let character = String(decoding: [byte], as: UTF8.self)
                        buffer += character
                        
                        // Safety check: prevent buffer from growing too large
                        if buffer.count > 100_000 {
                            print("[OpenAI] Warning: SSE buffer exceeded 100KB, clearing old data")
                            // Keep only the last 10KB
                            if let startIndex = buffer.index(buffer.endIndex, offsetBy: -10_000, limitedBy: buffer.startIndex) {
                                buffer = String(buffer[startIndex...])
                            }
                        }
                        
                        // Process complete SSE messages
                        while let range = buffer.range(of: "\n\n") {
                            let message = String(buffer[..<range.lowerBound])
                            
                            // Safely remove the processed portion from buffer
                            if range.upperBound < buffer.endIndex {
                                buffer = String(buffer[buffer.index(after: range.upperBound)...])
                            } else {
                                // We've reached the end of the buffer
                                buffer = ""
                            }
                            
                            if let content = parseSSEMessage(message) {
                                if content == "[DONE]" {
                                    print("[OpenAI] Stream completed. Total messages: \(messageCount)")
                                    continuation.finish()
                                    return
                                } else if !content.isEmpty {
                                    messageCount += 1
                                    print("[OpenAI] Received chunk #\(messageCount): \(content.prefix(20))...")
                                    continuation.yield(content)
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    print("[OpenAI] Error in stream processing: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    nonisolated func availableModels() -> [String] {
        return [
            "gpt-4-turbo-preview",
            "gpt-4",
            "gpt-4-vision-preview",
            "gpt-3.5-turbo",
            "gpt-3.5-turbo-16k"
        ]
    }
    
    nonisolated func defaultModel() -> String {
        return configuration.selectedModel
    }
    
    func validateConfiguration() async -> Bool {
        guard let apiKey = KeychainManager.getAPIKey(for: .openai) else {
            return false
        }
        
        do {
            // Test with a simple models endpoint
            var request = URLRequest(url: URL(string: "\(baseURL)/models")!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(
        content: String,
        images: [Data],
        chatHistory: [Message],
        apiKey: String
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw LLMServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build messages array
        var messages: [[String: Any]] = []
        
        // Add system prompt
        messages.append([
            "role": "system",
            "content": "You are a helpful AI assistant integrated into SideChat, a macOS sidebar application."
        ])
        
        // Add chat history
        for message in chatHistory {
            // Skip messages with empty content
            let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedContent.isEmpty && message.imageData == nil {
                print("[OpenAI] Skipping empty message with ID: \(message.id)")
                continue
            }
            
            if message.isUser {
                var userMessage: [String: Any] = ["role": "user"]
                
                // Handle images if present
                if let imageData = message.imageData, !images.isEmpty {
                    var messageContent: [[String: Any]] = []
                    messageContent.append(["type": "text", "text": message.content])
                    
                    if let base64Image = imageData.base64EncodedString() as String? {
                        messageContent.append([
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
                        ])
                    }
                    
                    userMessage["content"] = messageContent
                } else {
                    userMessage["content"] = message.content
                }
                
                messages.append(userMessage)
            } else {
                messages.append([
                    "role": "assistant",
                    "content": message.content
                ])
            }
        }
        
        // Add current message (only if it has content)
        let trimmedCurrentContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCurrentContent.isEmpty || !images.isEmpty {
            var currentMessage: [String: Any] = ["role": "user"]
            
            if !images.isEmpty {
                var messageContent: [[String: Any]] = []
                messageContent.append(["type": "text", "text": content])
                
                for imageData in images {
                    if let base64Image = imageData.base64EncodedString() as String? {
                        messageContent.append([
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
                        ])
                    }
                }
                
                currentMessage["content"] = messageContent
            } else {
                currentMessage["content"] = content
            }
            
            messages.append(currentMessage)
        } else {
            print("[OpenAI] Warning: Attempted to send empty message")
        }
        
        // Build request body
        let model = images.isEmpty ? defaultModel() : "gpt-4-vision-preview"
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": true,
            "temperature": 0.7,
            "max_tokens": 4096
        ]
        
        let requestData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestData
        
        // Log request details (without API key)
        print("[OpenAI] Request URL: \(url.absoluteString)")
        print("[OpenAI] Request model: \(model)")
        print("[OpenAI] Message count: \(messages.count)")
        if let requestString = String(data: requestData, encoding: .utf8) {
            // Remove API key from log
            let sanitized = requestString.replacingOccurrences(of: apiKey, with: "[REDACTED]")
            print("[OpenAI] Request body preview: \(sanitized.prefix(500))...")
        }
        
        return request
    }
    
    private func parseSSEMessage(_ message: String) -> String? {
        // Skip empty messages
        guard !message.isEmpty else { return nil }
        
        // Parse SSE format
        if message.hasPrefix("data: ") {
            let jsonString = String(message.dropFirst(6))
            
            // Handle [DONE] message
            if jsonString == "[DONE]" {
                return "[DONE]"
            }
            
            // Parse JSON
            if let data = jsonString.data(using: .utf8) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let delta = firstChoice["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        return content
                    } else {
                        print("[OpenAI] Failed to parse SSE JSON structure: \(jsonString)")
                    }
                } catch {
                    print("[OpenAI] JSON parsing error: \(error), data: \(jsonString)")
                }
            }
        }
        
        return nil
    }
    
    private func handleErrorResponse(statusCode: Int, data: Data) async throws {
        // Try to parse error message
        var errorMessage = "Unknown error"
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            errorMessage = message
        }
        
        switch statusCode {
        case 401:
            throw LLMServiceError.invalidAPIKey
        case 429:
            throw LLMServiceError.rateLimitExceeded
        case 400:
            if errorMessage.lowercased().contains("token") {
                throw LLMServiceError.tokenLimitExceeded
            } else {
                throw LLMServiceError.invalidResponse
            }
        case 500...599:
            throw LLMServiceError.networkError(NSError(
                domain: "OpenAI",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorMessage)"]
            ))
        default:
            throw LLMServiceError.unknownError(errorMessage)
        }
    }
}

// MARK: - Data Extension

private extension Data {
    func base64EncodedString() -> String? {
        return self.base64EncodedString(options: .lineLength64Characters)
    }
}