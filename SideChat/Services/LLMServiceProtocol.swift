import Foundation

// MARK: - LLM Service Protocol

/// Base protocol that all LLM service implementations must conform to
/// Provides a unified interface for streaming chat responses from various providers
protocol LLMServiceProtocol {
    /// The provider type for this service
    var provider: LLMProvider { get }
    
    /// Check if the service is properly configured (e.g., has valid API key)
    var isConfigured: Bool { get }
    
    /// Send a message to the LLM and receive a streaming response
    /// - Parameters:
    ///   - content: The text content of the message
    ///   - images: Optional array of image data to include with the message
    ///   - chatHistory: Previous messages in the conversation for context
    /// - Returns: An async stream of response chunks
    /// - Throws: LLMServiceError if the request fails
    func sendMessage(
        content: String,
        images: [Data],
        chatHistory: [Message]
    ) async throws -> AsyncThrowingStream<String, Error>
    
    /// Validate the service configuration (e.g., test API key)
    /// - Returns: True if the configuration is valid
    func validateConfiguration() async -> Bool
    
    /// Get the list of available models for this provider
    /// - Returns: Array of model identifiers
    func availableModels() -> [String]
    
    /// Get the default model for this provider
    /// - Returns: Model identifier string
    func defaultModel() -> String
}

// MARK: - LLM Service Error

/// Errors that can occur when interacting with LLM services
enum LLMServiceError: LocalizedError {
    case notConfigured
    case invalidAPIKey
    case networkError(Error)
    case rateLimitExceeded
    case invalidResponse
    case streamingError(String)
    case timeout
    case modelNotAvailable(String)
    case contentFilterTriggered
    case tokenLimitExceeded
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LLM service is not configured. Please add your API key in settings."
        case .invalidAPIKey:
            return "Invalid API key. Please check your settings."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .invalidResponse:
            return "Received invalid response from the service."
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .timeout:
            return "Request timed out. Please try again."
        case .modelNotAvailable(let model):
            return "Model '\(model)' is not available."
        case .contentFilterTriggered:
            return "Content was filtered by the service's safety systems."
        case .tokenLimitExceeded:
            return "The conversation is too long. Please start a new chat."
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - LLM Service Response

/// Represents a chunk of streaming response from an LLM
struct LLMStreamChunk {
    let content: String
    let isComplete: Bool
    let finishReason: String?
    let usage: TokenUsage?
}

// TokenUsage is already defined in LLMProvider.swift

// MARK: - Default Implementation

extension LLMServiceProtocol {
    /// Default implementation that returns true if configured
    func validateConfiguration() async -> Bool {
        return isConfigured
    }
}