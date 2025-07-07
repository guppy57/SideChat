import XCTest
import Foundation
@testable import SideChat

class LLMProviderTests: XCTestCase {
    
    // MARK: - LLMProvider Enum Tests
    
    func testLLMProviderProperties() {
        XCTAssertEqual(LLMProvider.openai.displayName, "OpenAI")
        XCTAssertEqual(LLMProvider.anthropic.displayName, "Anthropic")
        XCTAssertEqual(LLMProvider.google.displayName, "Google AI")
        XCTAssertEqual(LLMProvider.local.displayName, "Local Model")
        
        XCTAssertTrue(LLMProvider.openai.requiresAPIKey)
        XCTAssertTrue(LLMProvider.anthropic.requiresAPIKey)
        XCTAssertTrue(LLMProvider.google.requiresAPIKey)
        XCTAssertFalse(LLMProvider.local.requiresAPIKey)
        
        XCTAssertEqual(LLMProvider.openai.websiteURL, "https://openai.com")
        XCTAssertEqual(LLMProvider.anthropic.websiteURL, "https://anthropic.com")
        XCTAssertEqual(LLMProvider.google.websiteURL, "https://ai.google.dev")
        XCTAssertEqual(LLMProvider.local.websiteURL, "https://github.com/ggerganov/llama.cpp")
    }
    
    func testLLMProviderSerialization() {
        // Test Codable conformance
        let provider = LLMProvider.anthropic
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(provider)
        
        let decoder = JSONDecoder()
        let decodedProvider = try! decoder.decode(LLMProvider.self, from: data)
        
        XCTAssertEqual(provider, decodedProvider)
    }
    
    func testLLMProviderDefaultModels() {
        let openaiModels = LLMProvider.openai.defaultModels
        XCTAssertFalse(openaiModels.isEmpty)
        XCTAssertTrue(openaiModels.contains { $0.name == "gpt-4" })
        
        let anthropicModels = LLMProvider.anthropic.defaultModels
        XCTAssertFalse(anthropicModels.isEmpty)
        XCTAssertTrue(anthropicModels.contains { $0.name.contains("claude") })
        
        let googleModels = LLMProvider.google.defaultModels
        XCTAssertFalse(googleModels.isEmpty)
        XCTAssertTrue(googleModels.contains { $0.name.contains("gemini") })
        
        let localModels = LLMProvider.local.defaultModels
        XCTAssertFalse(localModels.isEmpty)
    }
    
    // MARK: - LLMModel Tests
    
    func testLLMModelCreation() {
        let model = LLMModel(
            id: "gpt-4",
            name: "gpt-4",
            displayName: "GPT-4",
            provider: .openai,
            maxTokens: 8192,
            contextLength: 8192,
            supportsImages: false,
            pricing: ModelPricing(inputTokenPrice: 0.03, outputTokenPrice: 0.06, currency: "USD")
        )
        
        XCTAssertEqual(model.id, "gpt-4")
        XCTAssertEqual(model.name, "gpt-4")
        XCTAssertEqual(model.displayName, "GPT-4")
        XCTAssertEqual(model.provider, .openai)
        XCTAssertEqual(model.maxTokens, 8192)
        XCTAssertEqual(model.contextLength, 8192)
        XCTAssertFalse(model.supportsImages)
        XCTAssertTrue(model.supportsStreaming)
        XCTAssertFalse(model.isDeprecated)
        XCTAssertNotNil(model.pricing)
    }
    
    func testLLMModelWithDefaultDisplayName() {
        let model = LLMModel(
            id: "test-model",
            name: "test-model",
            provider: .local,
            maxTokens: 2048,
            contextLength: 4096
        )
        
        XCTAssertEqual(model.displayName, "test-model") // Should use name as display name
    }
    
    func testLLMModelSerialization() {
        let pricing = ModelPricing(inputTokenPrice: 0.001, outputTokenPrice: 0.002, currency: "USD")
        let model = LLMModel(
            id: "test-model",
            name: "test-model",
            provider: .openai,
            maxTokens: 4096,
            contextLength: 8192,
            pricing: pricing
        )
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(model)
        
        let decoder = JSONDecoder()
        let decodedModel = try! decoder.decode(LLMModel.self, from: data)
        
        XCTAssertEqual(model.id, decodedModel.id)
        XCTAssertEqual(model.name, decodedModel.name)
        XCTAssertEqual(model.provider, decodedModel.provider)
        XCTAssertEqual(model.maxTokens, decodedModel.maxTokens)
        XCTAssertEqual(model.pricing?.inputTokenPrice, decodedModel.pricing?.inputTokenPrice)
    }
    
    // MARK: - ModelPricing Tests
    
    func testModelPricingCalculation() {
        let pricing = ModelPricing(inputTokenPrice: 0.03, outputTokenPrice: 0.06, currency: "USD")
        
        let cost = pricing.calculateCost(inputTokens: 1000, outputTokens: 500)
        let expectedCost = (1000.0 / 1000.0) * 0.03 + (500.0 / 1000.0) * 0.06
        XCTAssertEqual(cost, expectedCost, accuracy: 0.001)
        
        // Test with fractional tokens
        let cost2 = pricing.calculateCost(inputTokens: 1500, outputTokens: 750)
        let expectedCost2 = (1500.0 / 1000.0) * 0.03 + (750.0 / 1000.0) * 0.06
        XCTAssertEqual(cost2, expectedCost2, accuracy: 0.001)
    }
    
    func testModelPricingSerialization() {
        let pricing = ModelPricing(inputTokenPrice: 0.001, outputTokenPrice: 0.002, currency: "USD")
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(pricing)
        
        let decoder = JSONDecoder()
        let decodedPricing = try! decoder.decode(ModelPricing.self, from: data)
        
        XCTAssertEqual(pricing.inputTokenPrice, decodedPricing.inputTokenPrice)
        XCTAssertEqual(pricing.outputTokenPrice, decodedPricing.outputTokenPrice)
        XCTAssertEqual(pricing.currency, decodedPricing.currency)
    }
    
    // MARK: - TokenUsage Tests
    
    func testTokenUsageCalculation() {
        let usage = TokenUsage(promptTokens: 100, completionTokens: 50)
        
        XCTAssertEqual(usage.promptTokens, 100)
        XCTAssertEqual(usage.completionTokens, 50)
        XCTAssertEqual(usage.totalTokens, 150)
    }
    
    func testTokenUsageSerialization() {
        let usage = TokenUsage(promptTokens: 200, completionTokens: 100)
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(usage)
        
        let decoder = JSONDecoder()
        let decodedUsage = try! decoder.decode(TokenUsage.self, from: data)
        
        XCTAssertEqual(usage.promptTokens, decodedUsage.promptTokens)
        XCTAssertEqual(usage.completionTokens, decodedUsage.completionTokens)
        XCTAssertEqual(usage.totalTokens, decodedUsage.totalTokens)
    }
    
    // MARK: - LLMResponse Tests
    
    func testLLMResponseCreation() {
        let usage = TokenUsage(promptTokens: 50, completionTokens: 25)
        let response = LLMResponse(
            content: "Test response",
            model: "gpt-4",
            provider: .openai,
            usage: usage,
            finishReason: "stop",
            responseTime: 1.5
        )
        
        XCTAssertEqual(response.content, "Test response")
        XCTAssertEqual(response.model, "gpt-4")
        XCTAssertEqual(response.provider, .openai)
        XCTAssertEqual(response.usage?.totalTokens, 75)
        XCTAssertEqual(response.finishReason, "stop")
        XCTAssertEqual(response.responseTime, 1.5)
        XCTAssertNil(response.error)
    }
    
    func testLLMResponseWithError() {
        let error = LLMError(code: "rate_limit", message: "Rate limit exceeded", provider: .openai)
        let response = LLMResponse(
            content: "",
            model: "gpt-4",
            provider: .openai,
            responseTime: 0.0,
            error: error
        )
        
        XCTAssertTrue(response.content.isEmpty)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, "rate_limit")
        XCTAssertEqual(response.error?.message, "Rate limit exceeded")
    }
    
    func testLLMResponseSerialization() {
        let response = LLMResponse(
            content: "Serialization test",
            model: "claude-3",
            provider: .anthropic,
            responseTime: 2.0
        )
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(response)
        
        let decoder = JSONDecoder()
        let decodedResponse = try! decoder.decode(LLMResponse.self, from: data)
        
        XCTAssertEqual(response.content, decodedResponse.content)
        XCTAssertEqual(response.model, decodedResponse.model)
        XCTAssertEqual(response.provider, decodedResponse.provider)
        XCTAssertEqual(response.responseTime, decodedResponse.responseTime)
    }
    
    // MARK: - LLMStreamResponse Tests
    
    func testLLMStreamResponseCreation() {
        let streamResponse = LLMStreamResponse(
            delta: "Hello ",
            isComplete: false,
            model: "gpt-4",
            provider: .openai
        )
        
        XCTAssertEqual(streamResponse.delta, "Hello ")
        XCTAssertFalse(streamResponse.isComplete)
        XCTAssertEqual(streamResponse.model, "gpt-4")
        XCTAssertEqual(streamResponse.provider, .openai)
        XCTAssertNil(streamResponse.usage)
        XCTAssertNil(streamResponse.finishReason)
    }
    
    func testLLMStreamResponseCompletion() {
        let usage = TokenUsage(promptTokens: 10, completionTokens: 5)
        let completionResponse = LLMStreamResponse(
            delta: "",
            isComplete: true,
            model: "claude-3",
            provider: .anthropic,
            usage: usage,
            finishReason: "stop"
        )
        
        XCTAssertTrue(completionResponse.delta.isEmpty)
        XCTAssertTrue(completionResponse.isComplete)
        XCTAssertNotNil(completionResponse.usage)
        XCTAssertEqual(completionResponse.finishReason, "stop")
    }
    
    // MARK: - LLMError Tests
    
    func testLLMErrorCreation() {
        let error = LLMError(
            code: "invalid_request",
            message: "The request was invalid",
            details: "Missing required field: content",
            provider: .openai,
            isRetryable: false
        )
        
        XCTAssertEqual(error.code, "invalid_request")
        XCTAssertEqual(error.message, "The request was invalid")
        XCTAssertEqual(error.details, "Missing required field: content")
        XCTAssertEqual(error.provider, .openai)
        XCTAssertFalse(error.isRetryable)
        
        // Test LocalizedError conformance
        XCTAssertEqual(error.errorDescription, "The request was invalid")
        XCTAssertEqual(error.failureReason, "Missing required field: content")
    }
    
    func testLLMErrorRetryable() {
        let retryableError = LLMError(
            code: "rate_limit",
            message: "Rate limit exceeded",
            provider: .anthropic,
            isRetryable: true
        )
        
        XCTAssertTrue(retryableError.isRetryable)
        
        let nonRetryableError = LLMError(
            code: "invalid_api_key",
            message: "Invalid API key",
            provider: .openai,
            isRetryable: false
        )
        
        XCTAssertFalse(nonRetryableError.isRetryable)
    }
    
    // MARK: - LLMProviderFactory Tests
    
    func testLLMProviderFactoryCreation() {
        let openaiProvider = LLMProviderFactory.createProvider(for: .openai)
        XCTAssertEqual(openaiProvider.provider, .openai)
        XCTAssertTrue(openaiProvider is OpenAIProvider)
        
        let anthropicProvider = LLMProviderFactory.createProvider(for: .anthropic)
        XCTAssertEqual(anthropicProvider.provider, .anthropic)
        XCTAssertTrue(anthropicProvider is AnthropicProvider)
        
        let googleProvider = LLMProviderFactory.createProvider(for: .google)
        XCTAssertEqual(googleProvider.provider, .google)
        XCTAssertTrue(googleProvider is GoogleAIProvider)
        
        let localProvider = LLMProviderFactory.createProvider(for: .local)
        XCTAssertEqual(localProvider.provider, .local)
        XCTAssertTrue(localProvider is LocalModelProvider)
    }
    
    func testLLMProviderFactoryGetAllProviders() {
        let allProviders = LLMProviderFactory.getAllProviders()
        
        XCTAssertEqual(allProviders.count, 4)
        
        let providerTypes = allProviders.map { $0.provider }
        XCTAssertTrue(providerTypes.contains(.openai))
        XCTAssertTrue(providerTypes.contains(.anthropic))
        XCTAssertTrue(providerTypes.contains(.google))
        XCTAssertTrue(providerTypes.contains(.local))
    }
    
    // MARK: - Provider Implementation Tests
    
    func testOpenAIProviderProperties() {
        let provider = OpenAIProvider()
        
        XCTAssertEqual(provider.provider, .openai)
        XCTAssertEqual(provider.baseURL, "https://api.openai.com/v1")
        XCTAssertTrue(provider.supportsImages)
        XCTAssertTrue(provider.supportsStreaming)
        XCTAssertEqual(provider.maxTokens, 4096)
        XCTAssertEqual(provider.maxContextLength, 128000)
        XCTAssertFalse(provider.supportedModels.isEmpty)
    }
    
    func testAnthropicProviderProperties() {
        let provider = AnthropicProvider()
        
        XCTAssertEqual(provider.provider, .anthropic)
        XCTAssertEqual(provider.baseURL, "https://api.anthropic.com/v1")
        XCTAssertTrue(provider.supportsImages)
        XCTAssertTrue(provider.supportsStreaming)
        XCTAssertEqual(provider.maxTokens, 4096)
        XCTAssertEqual(provider.maxContextLength, 200000)
        XCTAssertFalse(provider.supportedModels.isEmpty)
    }
    
    func testGoogleAIProviderProperties() {
        let provider = GoogleAIProvider()
        
        XCTAssertEqual(provider.provider, .google)
        XCTAssertEqual(provider.baseURL, "https://generativelanguage.googleapis.com/v1")
        XCTAssertTrue(provider.supportsImages)
        XCTAssertTrue(provider.supportsStreaming)
        XCTAssertEqual(provider.maxTokens, 2048)
        XCTAssertEqual(provider.maxContextLength, 32768)
        XCTAssertFalse(provider.supportedModels.isEmpty)
    }
    
    func testLocalModelProviderProperties() {
        let provider = LocalModelProvider()
        
        XCTAssertEqual(provider.provider, .local)
        XCTAssertEqual(provider.baseURL, "http://localhost:8080")
        XCTAssertFalse(provider.supportsImages)
        XCTAssertTrue(provider.supportsStreaming)
        XCTAssertEqual(provider.maxTokens, 2048)
        XCTAssertEqual(provider.maxContextLength, 4096)
        XCTAssertFalse(provider.supportedModels.isEmpty)
    }
    
    func testProviderAPIKeyValidation() async {
        let openaiProvider = OpenAIProvider()
        
        // Test with no API key
        let noKeyResult = try! await openaiProvider.validateAPIKey()
        XCTAssertFalse(noKeyResult)
        
        // Test with empty API key
        openaiProvider.apiKey = ""
        let emptyKeyResult = try! await openaiProvider.validateAPIKey()
        XCTAssertFalse(emptyKeyResult)
        
        // Test with valid API key
        openaiProvider.apiKey = "sk-test-key"
        let validKeyResult = try! await openaiProvider.validateAPIKey()
        XCTAssertTrue(validKeyResult)
    }
    
    func testLocalProviderAPIKeyValidation() async {
        let localProvider = LocalModelProvider()
        
        // Local provider should always validate successfully
        let result = try! await localProvider.validateAPIKey()
        XCTAssertTrue(result)
    }
    
    func testProviderTokenEstimation() {
        let provider = OpenAIProvider()
        
        let shortText = "Hello"
        let shortTokens = provider.estimateTokens(for: shortText)
        XCTAssertGreaterThan(shortTokens, 0)
        XCTAssertLessThanOrEqual(shortTokens, 5)
        
        let longText = String(repeating: "word ", count: 100)
        let longTokens = provider.estimateTokens(for: longText)
        XCTAssertGreaterThan(longTokens, shortTokens)
        
        let emptyText = ""
        let emptyTokens = provider.estimateTokens(for: emptyText)
        XCTAssertEqual(emptyTokens, 1) // Minimum 1 token
    }
    
    func testProviderGetAvailableModels() async {
        let provider = OpenAIProvider()
        let models = try! await provider.getAvailableModels()
        
        XCTAssertFalse(models.isEmpty)
        XCTAssertEqual(models, provider.supportedModels)
    }
    
    func testProviderChatTitleGeneration() async {
        let provider = OpenAIProvider()
        let chatId = UUID()
        
        // Test with empty messages
        let emptyTitle = try! await provider.generateChatTitle(from: [])
        XCTAssertEqual(emptyTitle, "New Chat")
        
        // Test with messages
        let messages = [
            Message.createUserMessage(chatId: chatId, content: "Hello, can you help me with Swift programming?"),
            Message.createBotMessage(chatId: chatId, content: "Of course! I'd be happy to help.")
        ]
        
        let title = try! await provider.generateChatTitle(from: messages)
        XCTAssertFalse(title.isEmpty)
        XCTAssertNotEqual(title, "New Chat")
        XCTAssertLessThanOrEqual(title.count, 50)
        XCTAssertTrue(title.contains("Hello"))
    }
    
    func testProviderCreateRequest() {
        let provider = OpenAIProvider()
        let chatId = UUID()
        let history = [
            Message.createUserMessage(chatId: chatId, content: "Previous message"),
            Message.createBotMessage(chatId: chatId, content: "Previous response")
        ]
        
        let request = provider.createRequest(
            message: "Current message",
            model: "gpt-4",
            history: history,
            imageData: nil
        )
        
        XCTAssertEqual(request["model"] as? String, "gpt-4")
        XCTAssertEqual(request["max_tokens"] as? Int, provider.maxTokens)
        XCTAssertEqual(request["stream"] as? Bool, false)
        
        let messages = request["messages"] as? [[String: Any]]
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages?.count, 3) // 2 history + 1 current
        
        // Check message structure
        let firstMessage = messages?[0]
        XCTAssertEqual(firstMessage?["role"] as? String, "user")
        XCTAssertEqual(firstMessage?["content"] as? String, "Previous message")
        
        let lastMessage = messages?.last
        XCTAssertEqual(lastMessage?["role"] as? String, "user")
        XCTAssertEqual(lastMessage?["content"] as? String, "Current message")
    }
    
    func testProviderCreateStreamRequest() {
        let provider = AnthropicProvider()
        let chatId = UUID()
        let history: [Message] = []
        
        let request = provider.createStreamRequest(
            message: "Stream this message",
            model: "claude-3",
            history: history,
            imageData: nil
        )
        
        XCTAssertEqual(request["model"] as? String, "claude-3")
        XCTAssertEqual(request["stream"] as? Bool, true)
        
        let messages = request["messages"] as? [[String: Any]]
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages?.count, 1)
        
        let message = messages?[0]
        XCTAssertEqual(message?["role"] as? String, "user")
        XCTAssertEqual(message?["content"] as? String, "Stream this message")
    }
    
    // MARK: - Async Provider Tests
    
    func testProviderSendMessage() async {
        let provider = OpenAIProvider()
        let chatId = UUID()
        let history: [Message] = []
        
        let response = try! await provider.sendMessage(
            "Test message",
            model: "gpt-4",
            history: history,
            imageData: nil
        )
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertEqual(response.model, "gpt-4")
        XCTAssertEqual(response.provider, .openai)
        XCTAssertGreaterThan(response.responseTime, 0)
        XCTAssertNil(response.error)
    }
    
    func testProviderStreamMessage() async {
        let provider = AnthropicProvider()
        let chatId = UUID()
        let history: [Message] = []
        
        let stream = provider.streamMessage(
            "Stream test",
            model: "claude-3",
            history: history,
            imageData: nil
        )
        
        var responses: [LLMStreamResponse] = []
        var isComplete = false
        
        do {
            for try await response in stream {
                responses.append(response)
                if response.isComplete {
                    isComplete = true
                    break
                }
            }
        } catch {
            XCTFail("Stream should not throw error: \(error)")
        }
        
        XCTAssertFalse(responses.isEmpty)
        XCTAssertTrue(isComplete)
        
        // Verify all responses have correct metadata
        for response in responses {
            XCTAssertEqual(response.model, "claude-3")
            XCTAssertEqual(response.provider, .anthropic)
        }
        
        // Check that we received actual content
        let content = responses.compactMap { $0.delta }.joined()
        XCTAssertFalse(content.isEmpty)
    }
}