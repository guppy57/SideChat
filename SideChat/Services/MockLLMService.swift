import Foundation
import Defaults

/// Mock LLM Service for development and testing
/// Provides realistic streaming responses without requiring actual API connections
@MainActor
class MockLLMService: LLMServiceProtocol {
    
    // MARK: - Properties
    
    let provider: LLMProvider
    var isConfigured: Bool = true
    
    // Configuration options
    var responseDelay: UInt64 = 50_000_000 // 50ms between words
    var shouldSimulateErrors: Bool = false
    var errorRate: Double = 0.1 // 10% chance of error when errors enabled
    var responseStyle: ResponseStyle = .helpful
    
    // Response styles
    enum ResponseStyle {
        case helpful
        case creative
        case technical
        case concise
        case verbose
    }
    
    // MARK: - Initialization
    
    init(provider: LLMProvider = .openai) {
        self.provider = provider
    }
    
    // MARK: - LLMServiceProtocol Implementation
    
    func sendMessage(
        content: String,
        images: [Data],
        chatHistory: [Message]
    ) async throws -> AsyncThrowingStream<String, Error> {
        // Simulate configuration check
        guard isConfigured else {
            throw LLMServiceError.notConfigured
        }
        
        // Simulate random errors if enabled
        if shouldSimulateErrors && Double.random(in: 0...1) < errorRate {
            throw randomError()
        }
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms initial delay
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Generate appropriate response based on content
                    let response = generateResponse(for: content, images: images, history: chatHistory)
                    
                    // Stream the response
                    await streamResponse(response, to: continuation)
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func validateConfiguration() async -> Bool {
        // Simulate validation delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        return isConfigured
    }
    
    func availableModels() -> [String] {
        switch provider {
        case .openai:
            return ["gpt-4-turbo-preview", "gpt-4", "gpt-3.5-turbo"]
        case .anthropic:
            return ["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307"]
        case .google:
            return ["gemini-pro", "gemini-pro-vision"]
        case .local:
            return ["llama-2-7b", "mistral-7b", "mixtral-8x7b"]
        }
    }
    
    func defaultModel() -> String {
        switch provider {
        case .openai:
            return "gpt-4-turbo-preview"
        case .anthropic:
            return "claude-3-opus-20240229"
        case .google:
            return "gemini-pro"
        case .local:
            return "llama-2-7b"
        }
    }
    
    // MARK: - Response Generation
    
    private func generateResponse(for content: String, images: [Data], history: [Message]) -> String {
        let lowercased = content.lowercased()
        
        // Check for specific patterns
        if lowercased.contains("hello") || lowercased.contains("hi") {
            return generateGreeting()
        } else if lowercased.contains("help") {
            return generateHelpResponse()
        } else if lowercased.contains("code") || lowercased.contains("swift") || lowercased.contains("program") {
            return generateTechnicalResponse(about: content)
        } else if lowercased.contains("error") || lowercased.contains("bug") || lowercased.contains("issue") {
            return generateDebuggingResponse(about: content)
        } else if images.count > 0 {
            return generateImageResponse(imageCount: images.count)
        } else if lowercased.contains("test") {
            return generateTestResponse()
        } else {
            return generateGenericResponse(about: content, style: responseStyle)
        }
    }
    
    private func generateGreeting() -> String {
        let greetings = [
            "Hello! I'm here to help. What would you like to know or discuss today?",
            "Hi there! How can I assist you today? Feel free to ask me anything.",
            "Greetings! I'm ready to help with any questions or tasks you have.",
            "Hello! It's great to chat with you. What's on your mind?"
        ]
        return greetings.randomElement()!
    }
    
    private func generateHelpResponse() -> String {
        return """
        I'm a mock LLM service designed to help test the SideChat application. Here's what I can do:
        
        **General Assistance**
        - Answer questions on various topics
        - Provide explanations and summaries
        - Help with problem-solving
        
        **Technical Support**
        - Code examples and debugging help
        - SwiftUI and iOS development guidance
        - Software architecture discussions
        
        **Creative Tasks**
        - Writing assistance
        - Brainstorming ideas
        - Content generation
        
        **Image Analysis**
        - Describe images (simulated)
        - Answer questions about visual content
        
        Feel free to ask me anything, and I'll do my best to provide helpful responses!
        """
    }
    
    private func generateTechnicalResponse(about topic: String) -> String {
        if topic.lowercased().contains("swiftui") {
            return """
            SwiftUI is Apple's declarative framework for building user interfaces. Here are some key concepts:
            
            **View Protocol**
            ```swift
            struct ContentView: View {
                var body: some View {
                    Text("Hello, SwiftUI!")
                }
            }
            ```
            
            **State Management**
            - `@State`: For simple view-local state
            - `@Binding`: For two-way data binding
            - `@ObservedObject`: For external state objects
            - `@StateObject`: For owned reference types
            - `@EnvironmentObject`: For shared state across views
            
            **Layout System**
            - `VStack`, `HStack`, `ZStack` for layout
            - `Spacer()` for flexible spacing
            - `.frame()` for explicit sizing
            - `.padding()` for margins
            
            Would you like me to elaborate on any of these concepts?
            """
        } else {
            return """
            Based on your technical question about "\(topic.prefix(50))...", here's what I can tell you:
            
            **Key Concepts**
            1. Understanding the fundamentals is crucial
            2. Best practices should always be followed
            3. Performance optimization matters
            
            **Implementation Details**
            ```swift
            // Example implementation
            func processRequest() async throws {
                // Your code here
            }
            ```
            
            **Common Patterns**
            - Use async/await for asynchronous operations
            - Implement proper error handling
            - Follow SOLID principles
            
            Is there a specific aspect you'd like me to focus on?
            """
        }
    }
    
    private func generateDebuggingResponse(about issue: String) -> String {
        return """
        I understand you're experiencing an issue with "\(issue.prefix(50))...". Let's debug this together:
        
        **Debugging Steps**
        1. **Identify the Error**
           - Check the console for error messages
           - Look for crash logs or stack traces
           
        2. **Isolate the Problem**
           - Comment out recent changes
           - Use breakpoints to step through code
           - Add print statements for debugging
           
        3. **Common Causes**
           - Nil values or force unwrapping
           - Array index out of bounds
           - Incorrect data types
           - Missing protocol conformance
           
        4. **Solutions to Try**
           ```swift
           // Safe unwrapping
           if let value = optionalValue {
               // Use value safely
           }
           
           // Guard statements
           guard let data = getData() else {
               return
           }
           ```
        
        Would you like to share the specific error message or code snippet?
        """
    }
    
    private func generateImageResponse(imageCount: Int) -> String {
        return """
        I can see you've uploaded \(imageCount) image\(imageCount > 1 ? "s" : ""). While I'm a mock service and can't actually analyze images, in a real implementation I would:
        
        **Image Analysis Capabilities**
        - Describe the contents of the image
        - Identify objects, people, and text
        - Answer questions about what's shown
        - Provide context or explanations
        
        **Common Use Cases**
        - UI/UX feedback on screenshots
        - Code review from code images
        - Debugging visual issues
        - General image understanding
        
        Is there something specific you'd like to know about the image\(imageCount > 1 ? "s" : "")?
        """
    }
    
    private func generateTestResponse() -> String {
        return """
        🧪 **Test Response Generated Successfully!**
        
        This is a mock response demonstrating various formatting capabilities:
        
        **Text Formatting**
        - *Italic text* for emphasis
        - **Bold text** for importance
        - `Inline code` for technical terms
        
        **Lists**
        1. Ordered item one
        2. Ordered item two
        3. Ordered item three
        
        • Unordered item A
        • Unordered item B
        • Unordered item C
        
        **Code Block**
        ```swift
        func testFunction() -> String {
            return "This is a test!"
        }
        ```
        
        **Quote**
        > "The best way to predict the future is to invent it." - Alan Kay
        
        This demonstrates that the streaming and markdown rendering are working correctly!
        """
    }
    
    private func generateGenericResponse(about topic: String, style: ResponseStyle) -> String {
        let prefix = topic.prefix(100)
        
        switch style {
        case .helpful:
            return """
            I understand you're asking about "\(prefix)...". Let me provide you with a comprehensive response.
            
            **Overview**
            This is an interesting topic that involves several key aspects worth considering.
            
            **Key Points**
            1. First, it's important to understand the context
            2. Second, we should consider the implications
            3. Third, there are multiple approaches to consider
            
            **Recommendations**
            Based on what you've shared, I would suggest:
            - Taking a systematic approach
            - Considering all available options
            - Evaluating the pros and cons
            
            Would you like me to elaborate on any particular aspect?
            """
            
        case .creative:
            return """
            Ah, "\(prefix)..." - what a fascinating topic to explore! 🌟
            
            Imagine if we approached this from a completely different angle. What if the conventional wisdom is just the beginning?
            
            **Creative Perspectives**
            ✨ Think of it like a puzzle where each piece reveals a new dimension
            🎨 Consider the artistic elements that might be hiding in plain sight
            🚀 What if we pushed the boundaries beyond the expected?
            
            **Unconventional Ideas**
            - Reverse the typical approach
            - Combine seemingly unrelated concepts
            - Question the fundamental assumptions
            
            Sometimes the most innovative solutions come from the most unexpected places. What direction speaks to you?
            """
            
        case .technical:
            return generateTechnicalResponse(about: topic)
            
        case .concise:
            return """
            Regarding "\(prefix)...":
            
            • Direct answer: This requires careful consideration
            • Key factor: Context matters significantly
            • Action: Analyze requirements first
            
            Need specifics?
            """
            
        case .verbose:
            return """
            Your question about "\(prefix)..." touches upon a multifaceted subject that warrants a thorough exploration.
            
            **Introduction**
            To fully appreciate the nuances of this topic, we must first establish a comprehensive understanding of the underlying principles. The complexity inherent in this subject matter requires us to approach it from multiple angles.
            
            **Historical Context**
            Throughout the development of this field, numerous pioneers have contributed their insights. The evolution of thought in this area has been marked by significant paradigm shifts and breakthrough moments.
            
            **Theoretical Framework**
            The theoretical underpinnings of this topic rest upon several foundational concepts:
            1. The principle of systematic analysis
            2. The importance of empirical validation
            3. The role of iterative refinement
            4. The value of interdisciplinary perspectives
            
            **Practical Applications**
            In real-world scenarios, these concepts manifest in various ways. Practitioners in the field have developed sophisticated methodologies to address the challenges presented by this domain.
            
            **Contemporary Developments**
            Recent advances have opened new avenues for exploration. The cutting-edge research being conducted promises to revolutionize our understanding.
            
            **Future Directions**
            Looking ahead, several trends are emerging that will likely shape the trajectory of this field. The convergence of multiple disciplines is creating unprecedented opportunities.
            
            **Conclusion**
            In summary, this topic represents a rich area for continued investigation and application. The insights gained from deep study can be transformative.
            
            Would you like me to delve deeper into any particular aspect of this analysis?
            """
        }
    }
    
    // MARK: - Streaming
    
    private func streamResponse(_ response: String, to continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        // Split into words for streaming
        let words = response.split(separator: " ", omittingEmptySubsequences: false)
        
        for (index, word) in words.enumerated() {
            // Check for task cancellation
            if Task.isCancelled {
                continuation.finish()
                return
            }
            
            // Yield the word with space
            let chunk = String(word) + (index < words.count - 1 ? " " : "")
            continuation.yield(chunk)
            
            // Variable delay for more realistic streaming
            let delay = variableDelay()
            try? await Task.sleep(nanoseconds: delay)
        }
    }
    
    private func variableDelay() -> UInt64 {
        // Add some randomness to make streaming feel more natural
        let baseDelay = responseDelay
        let variation = Double.random(in: 0.5...1.5)
        return UInt64(Double(baseDelay) * variation)
    }
    
    // MARK: - Error Simulation
    
    private func randomError() -> Error {
        let errors: [LLMServiceError] = [
            .rateLimitExceeded,
            .timeout,
            .networkError(NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated network error"])),
            .invalidResponse,
            .tokenLimitExceeded
        ]
        return errors.randomElement()!
    }
}

// MARK: - Mock Service Configuration

extension MockLLMService {
    /// Configure the mock service for different testing scenarios
    func configure(for scenario: TestScenario) {
        switch scenario {
        case .fast:
            responseDelay = 10_000_000 // 10ms
            shouldSimulateErrors = false
            
        case .realistic:
            responseDelay = 50_000_000 // 50ms
            shouldSimulateErrors = false
            
        case .slow:
            responseDelay = 200_000_000 // 200ms
            shouldSimulateErrors = false
            
        case .flaky:
            responseDelay = 50_000_000 // 50ms
            shouldSimulateErrors = true
            errorRate = 0.3 // 30% error rate
            
        case .error:
            shouldSimulateErrors = true
            errorRate = 1.0 // Always error
        }
    }
    
    enum TestScenario {
        case fast
        case realistic
        case slow
        case flaky
        case error
    }
}