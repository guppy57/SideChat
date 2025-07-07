import Foundation

// MARK: - LLM Provider System

/// Protocol-based abstraction for different LLM providers (OpenAI, Anthropic, Google, Local)
/// Provides unified interface for chat completions, streaming, and model management

// MARK: - LLM Provider Protocol

protocol LLMProviderService {
    var provider: LLMProvider { get }
    var apiKey: String? { get set }
    var baseURL: String { get }
    var supportedModels: [LLMModel] { get }
    var supportsStreaming: Bool { get }
    var supportsImages: Bool { get }
    var maxTokens: Int { get }
    var maxContextLength: Int { get }
    
    func validateAPIKey() async throws -> Bool
    func getAvailableModels() async throws -> [LLMModel]
    func sendMessage(_ message: String, model: String, history: [Message], imageData: Data?) async throws -> LLMResponse
    func streamMessage(_ message: String, model: String, history: [Message], imageData: Data?) -> AsyncThrowingStream<LLMStreamResponse, Error>
    func generateChatTitle(from messages: [Message]) async throws -> String
    func estimateTokens(for text: String) -> Int
}

// MARK: - LLM Model

struct LLMModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let provider: LLMProvider
    let maxTokens: Int
    let contextLength: Int
    let supportsImages: Bool
    let supportsStreaming: Bool
    let isDeprecated: Bool
    let pricing: ModelPricing?
    let description: String?
    
    init(
        id: String,
        name: String,
        displayName: String? = nil,
        provider: LLMProvider,
        maxTokens: Int,
        contextLength: Int,
        supportsImages: Bool = false,
        supportsStreaming: Bool = true,
        isDeprecated: Bool = false,
        pricing: ModelPricing? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName ?? name
        self.provider = provider
        self.maxTokens = maxTokens
        self.contextLength = contextLength
        self.supportsImages = supportsImages
        self.supportsStreaming = supportsStreaming
        self.isDeprecated = isDeprecated
        self.pricing = pricing
        self.description = description
    }
}

// MARK: - Model Pricing

struct ModelPricing: Codable, Hashable {
    let inputTokenPrice: Double  // Price per 1K tokens
    let outputTokenPrice: Double // Price per 1K tokens
    let currency: String         // "USD"
    
    func calculateCost(inputTokens: Int, outputTokens: Int) -> Double {
        let inputCost = (Double(inputTokens) / 1000.0) * inputTokenPrice
        let outputCost = (Double(outputTokens) / 1000.0) * outputTokenPrice
        return inputCost + outputCost
    }
}

// MARK: - LLM Response

struct LLMResponse: Codable {
    let content: String
    let model: String
    let provider: LLMProvider
    let usage: TokenUsage?
    let finishReason: String?
    let responseTime: TimeInterval
    let timestamp: Date
    let error: LLMError?
    
    init(
        content: String,
        model: String,
        provider: LLMProvider,
        usage: TokenUsage? = nil,
        finishReason: String? = nil,
        responseTime: TimeInterval,
        timestamp: Date = Date(),
        error: LLMError? = nil
    ) {
        self.content = content
        self.model = model
        self.provider = provider
        self.usage = usage
        self.finishReason = finishReason
        self.responseTime = responseTime
        self.timestamp = timestamp
        self.error = error
    }
}

// MARK: - LLM Stream Response

struct LLMStreamResponse: Codable {
    let delta: String
    let isComplete: Bool
    let model: String
    let provider: LLMProvider
    let usage: TokenUsage?
    let finishReason: String?
    let timestamp: Date
    
    init(
        delta: String,
        isComplete: Bool = false,
        model: String,
        provider: LLMProvider,
        usage: TokenUsage? = nil,
        finishReason: String? = nil,
        timestamp: Date = Date()
    ) {
        self.delta = delta
        self.isComplete = isComplete
        self.model = model
        self.provider = provider
        self.usage = usage
        self.finishReason = finishReason
        self.timestamp = timestamp
    }
}

// MARK: - Token Usage

struct TokenUsage: Codable, Hashable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    init(promptTokens: Int, completionTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = promptTokens + completionTokens
    }
}

// MARK: - LLM Error

struct LLMError: LocalizedError, Codable, Hashable {
    let code: String
    let message: String
    let details: String?
    let provider: LLMProvider
    let timestamp: Date
    let isRetryable: Bool
    
    init(
        code: String,
        message: String,
        details: String? = nil,
        provider: LLMProvider,
        timestamp: Date = Date(),
        isRetryable: Bool = false
    ) {
        self.code = code
        self.message = message
        self.details = details
        self.provider = provider
        self.timestamp = timestamp
        self.isRetryable = isRetryable
    }
    
    var errorDescription: String? {
        return message
    }
    
    var failureReason: String? {
        return details
    }
}

// MARK: - Provider Factory

class LLMProviderFactory {
    static func createProvider(for type: LLMProvider) -> LLMProviderService {
        switch type {
        case .openai:
            return OpenAIProvider()
        case .anthropic:
            return AnthropicProvider()
        case .google:
            return GoogleAIProvider()
        case .local:
            return LocalModelProvider()
        }
    }
    
    static func getAllProviders() -> [LLMProviderService] {
        return LLMProvider.allCases.map { createProvider(for: $0) }
    }
    
    static func getProvider(for type: LLMProvider) -> LLMProviderService? {
        return createProvider(for: type)
    }
}

// MARK: - Provider Extensions

extension LLMProvider {
    var service: LLMProviderService {
        return LLMProviderFactory.createProvider(for: self)
    }
    
    var defaultModels: [LLMModel] {
        switch self {
        case .openai:
            return OpenAIProvider.defaultModels
        case .anthropic:
            return AnthropicProvider.defaultModels
        case .google:
            return GoogleAIProvider.defaultModels
        case .local:
            return LocalModelProvider.defaultModels
        }
    }
    
    var requiresAPIKey: Bool {
        switch self {
        case .openai, .anthropic, .google:
            return true
        case .local:
            return false
        }
    }
    
    var websiteURL: String {
        switch self {
        case .openai:
            return "https://openai.com"
        case .anthropic:
            return "https://anthropic.com"
        case .google:
            return "https://ai.google.dev"
        case .local:
            return "https://github.com/ggerganov/llama.cpp"
        }
    }
    
    var apiDocumentationURL: String {
        switch self {
        case .openai:
            return "https://platform.openai.com/docs"
        case .anthropic:
            return "https://docs.anthropic.com"
        case .google:
            return "https://ai.google.dev/docs"
        case .local:
            return "https://github.com/ggerganov/llama.cpp/blob/master/examples/server/README.md"
        }
    }
}

// MARK: - Base Provider Implementation

class BaseProvider: LLMProviderService {
    var provider: LLMProvider { fatalError("Must be implemented by subclass") }
    var apiKey: String?
    var baseURL: String { fatalError("Must be implemented by subclass") }
    var supportedModels: [LLMModel] { fatalError("Must be implemented by subclass") }
    var supportsStreaming: Bool { return true }
    var supportsImages: Bool { return false }
    var maxTokens: Int { return 4096 }
    var maxContextLength: Int { return 8192 }
    
    init() {
        self.apiKey = nil
    }
    
    func validateAPIKey() async throws -> Bool {
        fatalError("Must be implemented by subclass")
    }
    
    func getAvailableModels() async throws -> [LLMModel] {
        fatalError("Must be implemented by subclass")
    }
    
    func sendMessage(_ message: String, model: String, history: [Message], imageData: Data?) async throws -> LLMResponse {
        fatalError("Must be implemented by subclass")
    }
    
    func streamMessage(_ message: String, model: String, history: [Message], imageData: Data?) -> AsyncThrowingStream<LLMStreamResponse, Error> {
        fatalError("Must be implemented by subclass")
    }
    
    func generateChatTitle(from messages: [Message]) async throws -> String {
        guard !messages.isEmpty else {
            return "New Chat"
        }
        
        let firstUserMessage = messages.first { $0.isUser }?.content ?? ""
        let truncated = String(firstUserMessage.prefix(50))
        return truncated.isEmpty ? "New Chat" : truncated
    }
    
    func estimateTokens(for text: String) -> Int {
        // Simple estimation: ~4 characters per token
        return max(1, text.count / 4)
    }
    
    // MARK: - Helper Methods
    
    func createRequest(message: String, model: String, history: [Message], imageData: Data?) -> [String: Any] {
        var messages: [[String: Any]] = []
        
        // Add message history
        for historyMessage in history.suffix(20) { // Limit context
            let role = historyMessage.isUser ? "user" : "assistant"
            messages.append([
                "role": role,
                "content": historyMessage.content
            ])
        }
        
        // Add current message
        var currentMessage: [String: Any] = [
            "role": "user",
            "content": message
        ]
        
        if let imageData = imageData, supportsImages {
            // Provider-specific image handling would be implemented in subclasses
            currentMessage["content"] = [
                ["type": "text", "text": message],
                ["type": "image", "image": imageData.base64EncodedString()]
            ]
        }
        
        messages.append(currentMessage)
        
        return [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "stream": false
        ]
    }
    
    func createStreamRequest(message: String, model: String, history: [Message], imageData: Data?) -> [String: Any] {
        var request = createRequest(message: message, model: model, history: history, imageData: imageData)
        request["stream"] = true
        return request
    }
}

// MARK: - Placeholder Provider Implementations

class OpenAIProvider: BaseProvider {
    override var provider: LLMProvider { return .openai }
    override var baseURL: String { return "https://api.openai.com/v1" }
    override var supportedModels: [LLMModel] { return Self.defaultModels }
    override var supportsImages: Bool { return true }
    override var maxTokens: Int { return 4096 }
    override var maxContextLength: Int { return 128000 }
    
    static let defaultModels: [LLMModel] = [
        LLMModel(
            id: "gpt-4",
            name: "gpt-4",
            displayName: "GPT-4",
            provider: .openai,
            maxTokens: 8192,
            contextLength: 8192,
            supportsImages: false,
            pricing: ModelPricing(inputTokenPrice: 0.03, outputTokenPrice: 0.06, currency: "USD")
        ),
        LLMModel(
            id: "gpt-4-vision-preview",
            name: "gpt-4-vision-preview",
            displayName: "GPT-4 Vision",
            provider: .openai,
            maxTokens: 4096,
            contextLength: 128000,
            supportsImages: true,
            pricing: ModelPricing(inputTokenPrice: 0.01, outputTokenPrice: 0.03, currency: "USD")
        ),
        LLMModel(
            id: "gpt-3.5-turbo",
            name: "gpt-3.5-turbo",
            displayName: "GPT-3.5 Turbo",
            provider: .openai,
            maxTokens: 4096,
            contextLength: 16385,
            pricing: ModelPricing(inputTokenPrice: 0.001, outputTokenPrice: 0.002, currency: "USD")
        )
    ]
    
    override func validateAPIKey() async throws -> Bool {
        // Placeholder implementation
        return apiKey != nil && !apiKey!.isEmpty
    }
    
    override func getAvailableModels() async throws -> [LLMModel] {
        return supportedModels
    }
    
    override func sendMessage(_ message: String, model: String, history: [Message], imageData: Data?) async throws -> LLMResponse {
        // Placeholder implementation
        return LLMResponse(
            content: "This is a placeholder response from OpenAI",
            model: model,
            provider: provider,
            responseTime: 1.0
        )
    }
    
    override func streamMessage(_ message: String, model: String, history: [Message], imageData: Data?) -> AsyncThrowingStream<LLMStreamResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                // Placeholder streaming implementation
                let words = "This is a placeholder streaming response from OpenAI".components(separatedBy: " ")
                for word in words {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                    continuation.yield(LLMStreamResponse(
                        delta: word + " ",
                        model: model,
                        provider: provider
                    ))
                }
                continuation.yield(LLMStreamResponse(
                    delta: "",
                    isComplete: true,
                    model: model,
                    provider: provider
                ))
                continuation.finish()
            }
        }
    }
}

class AnthropicProvider: BaseProvider {
    override var provider: LLMProvider { return .anthropic }
    override var baseURL: String { return "https://api.anthropic.com/v1" }
    override var supportedModels: [LLMModel] { return Self.defaultModels }
    override var supportsImages: Bool { return true }
    override var maxTokens: Int { return 4096 }
    override var maxContextLength: Int { return 200000 }
    
    static let defaultModels: [LLMModel] = [
        LLMModel(
            id: "claude-3-sonnet-20240229",
            name: "claude-3-sonnet-20240229",
            displayName: "Claude 3 Sonnet",
            provider: .anthropic,
            maxTokens: 4096,
            contextLength: 200000,
            supportsImages: true,
            pricing: ModelPricing(inputTokenPrice: 0.003, outputTokenPrice: 0.015, currency: "USD")
        ),
        LLMModel(
            id: "claude-3-opus-20240229",
            name: "claude-3-opus-20240229",
            displayName: "Claude 3 Opus",
            provider: .anthropic,
            maxTokens: 4096,
            contextLength: 200000,
            supportsImages: true,
            pricing: ModelPricing(inputTokenPrice: 0.015, outputTokenPrice: 0.075, currency: "USD")
        )
    ]
    
    override func validateAPIKey() async throws -> Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }
    
    override func getAvailableModels() async throws -> [LLMModel] {
        return supportedModels
    }
    
    override func sendMessage(_ message: String, model: String, history: [Message], imageData: Data?) async throws -> LLMResponse {
        return LLMResponse(
            content: "This is a placeholder response from Anthropic",
            model: model,
            provider: provider,
            responseTime: 1.2
        )
    }
    
    override func streamMessage(_ message: String, model: String, history: [Message], imageData: Data?) -> AsyncThrowingStream<LLMStreamResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let words = "This is a placeholder streaming response from Anthropic".components(separatedBy: " ")
                for word in words {
                    try await Task.sleep(nanoseconds: 150_000_000)
                    continuation.yield(LLMStreamResponse(
                        delta: word + " ",
                        model: model,
                        provider: provider
                    ))
                }
                continuation.yield(LLMStreamResponse(
                    delta: "",
                    isComplete: true,
                    model: model,
                    provider: provider
                ))
                continuation.finish()
            }
        }
    }
}

class GoogleAIProvider: BaseProvider {
    override var provider: LLMProvider { return .google }
    override var baseURL: String { return "https://generativelanguage.googleapis.com/v1" }
    override var supportedModels: [LLMModel] { return Self.defaultModels }
    override var supportsImages: Bool { return true }
    override var maxTokens: Int { return 2048 }
    override var maxContextLength: Int { return 32768 }
    
    static let defaultModels: [LLMModel] = [
        LLMModel(
            id: "gemini-pro",
            name: "gemini-pro",
            displayName: "Gemini Pro",
            provider: .google,
            maxTokens: 2048,
            contextLength: 32768,
            pricing: ModelPricing(inputTokenPrice: 0.00025, outputTokenPrice: 0.0005, currency: "USD")
        ),
        LLMModel(
            id: "gemini-pro-vision",
            name: "gemini-pro-vision",
            displayName: "Gemini Pro Vision",
            provider: .google,
            maxTokens: 2048,
            contextLength: 16384,
            supportsImages: true,
            pricing: ModelPricing(inputTokenPrice: 0.00025, outputTokenPrice: 0.0005, currency: "USD")
        )
    ]
    
    override func validateAPIKey() async throws -> Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }
    
    override func getAvailableModels() async throws -> [LLMModel] {
        return supportedModels
    }
    
    override func sendMessage(_ message: String, model: String, history: [Message], imageData: Data?) async throws -> LLMResponse {
        return LLMResponse(
            content: "This is a placeholder response from Google AI",
            model: model,
            provider: provider,
            responseTime: 0.8
        )
    }
    
    override func streamMessage(_ message: String, model: String, history: [Message], imageData: Data?) -> AsyncThrowingStream<LLMStreamResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let words = "This is a placeholder streaming response from Google AI".components(separatedBy: " ")
                for word in words {
                    try await Task.sleep(nanoseconds: 120_000_000)
                    continuation.yield(LLMStreamResponse(
                        delta: word + " ",
                        model: model,
                        provider: provider
                    ))
                }
                continuation.yield(LLMStreamResponse(
                    delta: "",
                    isComplete: true,
                    model: model,
                    provider: provider
                ))
                continuation.finish()
            }
        }
    }
}

class LocalModelProvider: BaseProvider {
    override var provider: LLMProvider { return .local }
    override var baseURL: String { return "http://localhost:8080" }
    override var supportedModels: [LLMModel] { return Self.defaultModels }
    override var supportsImages: Bool { return false }
    override var maxTokens: Int { return 2048 }
    override var maxContextLength: Int { return 4096 }
    
    static let defaultModels: [LLMModel] = [
        LLMModel(
            id: "local-model",
            name: "local-model",
            displayName: "Local Model",
            provider: .local,
            maxTokens: 2048,
            contextLength: 4096,
            description: "Local language model running via llama.cpp server"
        )
    ]
    
    override func validateAPIKey() async throws -> Bool {
        // Local models don't require API keys
        return true
    }
    
    override func getAvailableModels() async throws -> [LLMModel] {
        return supportedModels
    }
    
    override func sendMessage(_ message: String, model: String, history: [Message], imageData: Data?) async throws -> LLMResponse {
        return LLMResponse(
            content: "This is a placeholder response from local model",
            model: model,
            provider: provider,
            responseTime: 2.0
        )
    }
    
    override func streamMessage(_ message: String, model: String, history: [Message], imageData: Data?) -> AsyncThrowingStream<LLMStreamResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let words = "This is a placeholder streaming response from local model".components(separatedBy: " ")
                for word in words {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    continuation.yield(LLMStreamResponse(
                        delta: word + " ",
                        model: model,
                        provider: provider
                    ))
                }
                continuation.yield(LLMStreamResponse(
                    delta: "",
                    isComplete: true,
                    model: model,
                    provider: provider
                ))
                continuation.finish()
            }
        }
    }
}