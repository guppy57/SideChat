import Foundation
import SwiftUI
import Combine
import Defaults

// MARK: - Chat View Model

/// Main view model for managing chat state and operations
/// Handles message sending, streaming responses, and database persistence
@MainActor
class ChatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var messages: [Message] = []
    @Published private(set) var isTyping = false
    @Published private(set) var currentStreamingMessage: Message?
    @Published var error: Error?
    @Published private(set) var isLoading = false
    @Published private(set) var lastMessageUpdate = Date()
    @Published private(set) var throttledScrollUpdate = Date()
    
    // Scroll throttling
    private var scrollThrottleTimer: Timer?
    private let scrollThrottleInterval = 0.033 // 33ms for 30fps smooth scrolling
    
    // MARK: - Properties
    
    let chatId: UUID
    private let databaseManager: DatabaseManager
    private var llmService: LLMServiceProtocol?
    private var streamingTask: Task<Void, Never>?
    
    // Settings
    @Default(.defaultLLMProvider) private var defaultProvider
    
    // MARK: - Initialization
    
    init(chatId: UUID? = nil, useMockService: Bool = true) {
        self.chatId = chatId ?? UUID()
        self.databaseManager = DatabaseManager.shared
        
        // Initialize mock service for development
        // TODO: Replace with real service initialization based on settings
        if useMockService {
            self.llmService = MockLLMService(provider: defaultProvider)
        }
        
        // Load messages on init
        Task {
            await loadMessages()
        }
    }
    
    deinit {
        streamingTask?.cancel()
        scrollThrottleTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Load messages from database
    func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Load from database
        // For now, use mock data if no messages exist
        if messages.isEmpty {
            loadMockMessages()
        }
    }
    
    /// Send a new message
    /// - Parameters:
    ///   - content: The text content of the message
    ///   - images: Optional images to include
    func sendMessage(content: String, images: [Data] = []) {
        // Trim whitespace
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate message
        guard !trimmedContent.isEmpty || !images.isEmpty else { return }
        
        // Cancel any existing streaming
        streamingTask?.cancel()
        
        // Create user message
        let userMessage = Message.createUserMessage(
            chatId: chatId,
            content: trimmedContent,
            imageData: images.first // TODO: Support multiple images
        )
        
        // Add to messages array
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.append(userMessage)
        }
        
        // Save to database (async)
        Task {
            do {
                try await databaseManager.saveMessage(userMessage)
            } catch {
                print("Failed to save user message: \(error)")
            }
        }
        
        // Start LLM response
        streamingTask = Task {
            await handleLLMResponse(for: userMessage)
        }
    }
    
    /// Retry the last failed message
    func retryLastMessage() {
        guard let lastBotMessage = messages.last(where: { !$0.isUser && $0.status == .failed }) else {
            return
        }
        
        // Find the user message before it
        guard let messageIndex = messages.firstIndex(where: { $0.id == lastBotMessage.id }),
              messageIndex > 0,
              messages[messageIndex - 1].isUser else {
            return
        }
        
        let userMessage = messages[messageIndex - 1]
        
        // Remove the failed bot message
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.removeAll { $0.id == lastBotMessage.id }
        }
        
        // Retry
        streamingTask = Task {
            await handleLLMResponse(for: userMessage)
        }
    }
    
    /// Delete a message
    /// - Parameter id: The ID of the message to delete
    func deleteMessage(id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.removeAll { $0.id == id }
        }
        
        // Delete from database (async)
        Task {
            do {
                try await databaseManager.deleteMessage(id: id)
            } catch {
                print("Failed to delete message: \(error)")
            }
        }
    }
    
    /// Update a message's content
    /// - Parameters:
    ///   - id: The message ID
    ///   - content: The new content
    func updateMessage(id: UUID, content: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        
        messages[index].content = content
        messages[index].editedAt = Date()
        
        // Update in database (async)
        // TODO: Implement updateMessage in DatabaseManager
        // Task {
        //     do {
        //         try await databaseManager.updateMessage(messages[index])
        //     } catch {
        //         print("Failed to update message: \(error)")
        //     }
        // }
    }
    
    // MARK: - Private Methods
    
    /// Handle LLM response for a user message
    private func handleLLMResponse(for userMessage: Message) async {
        // Show typing indicator
        withAnimation(.easeInOut(duration: 0.2)) {
            isTyping = true
        }
        
        // Create bot message
        var botMessage = Message.createBotMessage(
            chatId: chatId,
            content: "",
            metadata: MessageMetadata(
                model: getDefaultModel(),
                provider: defaultProvider
            ),
            status: .streaming
        )
        
        // Add to messages
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.append(botMessage)
            currentStreamingMessage = botMessage
            isTyping = false  // Hide typing indicator when streaming starts
        }
        
        do {
            // Use LLM service (mock or real)
            guard let service = llmService else {
                throw LLMServiceError.notConfigured
            }
            
            let stream = try await service.sendMessage(
                content: userMessage.content,
                images: userMessage.imageData != nil ? [userMessage.imageData!] : [],
                chatHistory: messages.dropLast() // Exclude the bot message we just added
            )
            
            // Process stream
            for try await chunk in stream {
                botMessage.appendContent(chunk)
                updateStreamingMessage(botMessage)
            }
            
            // Mark as complete
            botMessage.setStatus(MessageStatus.sent)
            finalizeMessage(botMessage)
            
        } catch {
            // Handle error
            self.error = error
            botMessage.markAsFailed(error: MessageError(
                code: "llm_error",
                message: error.localizedDescription
            ))
            finalizeMessage(botMessage)
        }
    }
    
    
    /// Update the streaming message in the array
    private func updateStreamingMessage(_ message: Message) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        withAnimation(.easeInOut(duration: 0.1)) {
            messages[index] = message
            lastMessageUpdate = Date()
            scheduleThrottledScrollUpdate()
        }
    }
    
    /// Schedule a throttled scroll update to prevent jittery scrolling
    private func scheduleThrottledScrollUpdate() {
        // Cancel existing timer
        scrollThrottleTimer?.invalidate()
        
        // Schedule new timer
        scrollThrottleTimer = Timer.scheduledTimer(withTimeInterval: scrollThrottleInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.throttledScrollUpdate = Date()
            }
        }
    }
    
    /// Finalize a message after streaming completes
    private func finalizeMessage(_ message: Message) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            messages[index] = message
            currentStreamingMessage = nil
            isTyping = false
            // Cancel any pending throttled update and trigger immediate update
            scrollThrottleTimer?.invalidate()
            throttledScrollUpdate = Date()
        }
        
        // Save to database
        Task {
            do {
                try await databaseManager.saveMessage(message)
            } catch {
                print("Failed to save bot message: \(error)")
            }
        }
    }
    
    /// Load mock messages for testing
    private func loadMockMessages() {
        messages = [
            Message.createUserMessage(
                chatId: chatId,
                content: "Hello! Can you help me understand SwiftUI better?"
            ),
            Message.createBotMessage(
                chatId: chatId,
                content: "Of course! I'd be happy to help you understand SwiftUI better. SwiftUI is Apple's modern declarative framework for building user interfaces across all Apple platforms.\n\nWhat specific aspect of SwiftUI would you like to explore? Here are some areas we could dive into:\n\n• **Views and Modifiers** - The building blocks of SwiftUI\n• **State Management** - @State, @Binding, @ObservedObject, etc.\n• **Layout System** - Stacks, Grids, and custom layouts\n• **Animations** - Creating smooth, declarative animations\n• **Data Flow** - How data moves through your app\n\nWhat interests you most?",
                status: .sent
            ),
            Message.createUserMessage(
                chatId: chatId,
                content: "I'm particularly interested in understanding state management. When should I use @State vs @StateObject?"
            ),
            Message.createBotMessage(
                chatId: chatId,
                content: "Great question! Understanding when to use `@State` vs `@StateObject` is crucial for proper state management in SwiftUI. Let me break it down:\n\n## @State\n\nUse `@State` for:\n• **Simple value types** (String, Int, Bool, structs)\n• **View-local state** that doesn't need to be shared\n• **Temporary UI state** (toggle states, text field values)\n\n```swift\n@State private var isShowingAlert = false\n@State private var username = \"\"\n@State private var counter = 0\n```\n\n## @StateObject\n\nUse `@StateObject` for:\n• **Reference types** (classes conforming to ObservableObject)\n• **View models** that manage complex state\n• **State that needs to survive view updates**\n• **When you're creating/owning the object**\n\n```swift\n@StateObject private var viewModel = ChatViewModel()\n@StateObject private var networkManager = NetworkManager()\n```\n\n## Key Differences\n\n1. **Lifetime**: `@State` is tied to the view's lifetime, while `@StateObject` survives view updates\n2. **Type**: `@State` is for value types, `@StateObject` is for reference types\n3. **Ownership**: Use `@StateObject` when creating the object, `@ObservedObject` when receiving it\n\nWould you like to see more examples or explore other property wrappers like `@ObservedObject` or `@EnvironmentObject`?",
                status: .sent
            )
        ]
    }
    
    /// Get the default model for the current provider
    private func getDefaultModel() -> String {
        switch defaultProvider {
        case .openai:
            return "gpt-4-turbo-preview"
        case .anthropic:
            return "claude-3-opus-20240229"
        case .google:
            return "gemini-pro"
        case .local:
            return "local-model"
        }
    }
    
    // MARK: - Public Computed Properties
    
    /// Check if there are any messages
    var hasMessages: Bool {
        !messages.isEmpty
    }
    
    /// Get the last message
    var lastMessage: Message? {
        messages.last
    }
    
    /// Check if the last message is from the user
    var isWaitingForResponse: Bool {
        guard let lastMessage = lastMessage else { return false }
        return lastMessage.isUser && !isTyping
    }
    
    /// Get messages for export
    func exportMessages() -> [Message] {
        messages
    }
}