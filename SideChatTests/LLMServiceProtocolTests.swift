import Testing
import Foundation
@testable import SideChat

// MARK: - Mock LLM Service

class MockLLMService: LLMServiceProtocol {
    var provider: LLMProvider = .openai
    var isConfigured: Bool = true
    var shouldFail: Bool = false
    
    func sendMessage(content: String, images: [Data], chatHistory: [Message]) async throws -> AsyncThrowingStream<String, Error> {
        if shouldFail {
            throw LLMServiceError.notConfigured
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                let words = "This is a mock response".split(separator: " ")
                for word in words {
                    continuation.yield(String(word) + " ")
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                continuation.finish()
            }
        }
    }
    
    func availableModels() -> [String] {
        return ["gpt-4", "gpt-3.5-turbo"]
    }
    
    func defaultModel() -> String {
        return "gpt-4"
    }
}

// MARK: - LLM Service Protocol Tests

@Suite("LLMServiceProtocol Tests")
struct LLMServiceProtocolTests {
    
    @Test("LLMServiceError provides correct descriptions")
    func testErrorDescriptions() {
        #expect(LLMServiceError.notConfigured.localizedDescription.contains("not configured"))
        #expect(LLMServiceError.invalidAPIKey.localizedDescription.contains("Invalid API key"))
        #expect(LLMServiceError.rateLimitExceeded.localizedDescription.contains("Rate limit"))
        #expect(LLMServiceError.timeout.localizedDescription.contains("timed out"))
        #expect(LLMServiceError.tokenLimitExceeded.localizedDescription.contains("too long"))
    }
    
    @Test("Mock service implements protocol correctly")
    func testMockServiceImplementation() {
        let service = MockLLMService()
        
        #expect(service.provider == .openai)
        #expect(service.isConfigured == true)
        #expect(service.availableModels().count > 0)
        #expect(service.defaultModel() == "gpt-4")
    }
    
    @Test("Mock service can stream response")
    func testMockServiceStreaming() async throws {
        let service = MockLLMService()
        
        let stream = try await service.sendMessage(
            content: "Test",
            images: [],
            chatHistory: []
        )
        
        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        
        #expect(chunks.count > 0)
        #expect(chunks.joined().contains("mock response"))
    }
    
    @Test("Mock service handles errors")
    func testMockServiceError() async {
        let service = MockLLMService()
        service.shouldFail = true
        
        do {
            _ = try await service.sendMessage(
                content: "Test",
                images: [],
                chatHistory: []
            )
            Issue.record("Expected error but none was thrown")
        } catch {
            #expect(error is LLMServiceError)
        }
    }
    
    @Test("Default validateConfiguration implementation")
    func testDefaultValidateConfiguration() async {
        let service = MockLLMService()
        
        let isValid = await service.validateConfiguration()
        #expect(isValid == true)
        
        service.isConfigured = false
        let isInvalid = await service.validateConfiguration()
        #expect(isInvalid == false)
    }
    
    @Test("LLMStreamChunk structure")
    func testLLMStreamChunk() {
        let usage = TokenUsage(
            promptTokens: 10,
            completionTokens: 20
        )
        
        let chunk = LLMStreamChunk(
            content: "Hello",
            isComplete: false,
            finishReason: nil,
            usage: usage
        )
        
        #expect(chunk.content == "Hello")
        #expect(chunk.isComplete == false)
        #expect(chunk.finishReason == nil)
        #expect(chunk.usage?.totalTokens == 30)
    }
}