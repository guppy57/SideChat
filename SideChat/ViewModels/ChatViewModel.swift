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
    @Published private(set) var shouldScrollToBottom = false
    
    // Scroll throttling
    private var scrollThrottleTimer: Timer?
    private let scrollThrottleInterval = 0.033 // 33ms for 30fps smooth scrolling
    
    // MARK: - Properties
    
    private(set) var chatId: UUID
    private let databaseManager: DatabaseManager
    private var streamingTask: Task<Void, Never>?
    
    // Current provider configuration
    @Published private(set) var currentProviderId: UUID?
    @Published private(set) var currentService: LLMServiceProtocol?
    @Published private(set) var availableProviders: [ProviderConfiguration] = []
    
    // Settings
    @Default(.defaultLLMProvider) private var defaultProvider
    @Default(.providerConfigurations) private var providerConfigurations
    
    // Provider configuration status observation
    @Default(.hasConfiguredOpenAI) private var hasConfiguredOpenAI
    @Default(.hasConfiguredAnthropic) private var hasConfiguredAnthropic
    @Default(.hasConfiguredGoogleAI) private var hasConfiguredGoogleAI
    @Default(.hasConfiguredLocalModel) private var hasConfiguredLocalModel
    
    // Model selection
    @Default(.selectedOpenAIModel) private var selectedOpenAIModel
    @Default(.selectedAnthropicModel) private var selectedAnthropicModel
    @Default(.selectedGoogleModel) private var selectedGoogleModel
    
    private let forceUseMockService: Bool
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(chatId: UUID? = nil, databaseManager: DatabaseManager? = nil, forceUseMockService: Bool = false, autoLoadMessages: Bool = true) {
        self.chatId = chatId ?? UUID()
        self.databaseManager = databaseManager ?? DatabaseManager.shared
        self.forceUseMockService = forceUseMockService
        
        // Initialize appropriate LLM service based on configuration
        loadAvailableProviders()
        setupDefaultService()
        
        // Load messages on init only if not in test environment and autoLoadMessages is true
        // This prevents crashes when DatabaseManager.shared isn't initialized during tests
        let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if autoLoadMessages && !isTestEnvironment {
            Task {
                await loadMessages()
            }
        }
        
        // Observe provider changes and recreate service when needed
        setupProviderObservation()
    }
    
    deinit {
        streamingTask?.cancel()
        scrollThrottleTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Load recent messages from database with pagination for performance
    func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load only recent 100 messages for performance
            messages = try await databaseManager.loadRecentMessages(for: chatId, limit: 100)
            
            // Trigger scroll to bottom after messages are loaded
            shouldScrollToBottom = true
            
            // If no messages exist, don't load mock data
            // Let the user start fresh
        } catch {
            print("Failed to load messages: \(error)")
            self.error = error
        }
    }
    
    /// Load all messages from database (for search/export features)
    func loadAllMessages() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            messages = try await databaseManager.loadMessages(for: chatId)
            
            // Trigger scroll to bottom after messages are loaded
            shouldScrollToBottom = true
        } catch {
            print("Failed to load all messages: \(error)")
            self.error = error
        }
    }
    
    /// Load messages for a specific chat
    func loadMessages(for chatId: UUID) {
        // Cancel any existing streaming
        streamingTask?.cancel()
        
        // Update chat ID
        self.chatId = chatId
        
        // Clear current messages
        messages = []
        currentStreamingMessage = nil
        isTyping = false
        error = nil
        
        // Load new messages
        Task {
            await loadMessages()
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
                // If this is the first message, create and save the chat
                if messages.count == 1 {
                    let newChat = Chat(
                        id: chatId,  // Use existing chat ID
                        title: generateChatTitle(from: trimmedContent),
                        createdAt: Date(),
                        updatedAt: Date(),
                        llmProvider: defaultProvider,
                        modelName: getDefaultModel(),
                        isArchived: false,
                        messageCount: 1,
                        lastMessagePreview: trimmedContent
                    )
                    try await databaseManager.saveChat(newChat)
                }
                
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
        print("🔥 DELETE MESSAGE called for ID: \(id)")
        print("  Messages before deletion: \(messages.count)")
        print("  Message IDs: \(messages.map { $0.id.uuidString.prefix(8) }.joined(separator: ", "))")
        
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.removeAll { $0.id == id }
        }
        
        print("  Messages after deletion: \(messages.count)")
        print("  Remaining IDs: \(messages.map { $0.id.uuidString.prefix(8) }.joined(separator: ", "))")
        
        // Delete from database (async)
        Task {
            do {
                try await databaseManager.deleteMessage(id: id)
                print("  ✅ Database deletion successful")
            } catch {
                print("  ❌ Failed to delete message from database: \(error)")
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
        
        // Create bot message with current provider configuration
        let currentConfig = providerConfigurations.first(where: { $0.id == currentProviderId })
        var botMessage = Message.createBotMessage(
            chatId: chatId,
            content: "",
            metadata: MessageMetadata(
                model: currentConfig?.selectedModel ?? getDefaultModel(),
                provider: currentConfig?.provider ?? defaultProvider,
                providerConfigId: currentProviderId
            ),
            status: .streaming
        )
        
        // Don't add the message yet - keep typing indicator showing
        currentStreamingMessage = botMessage
        
        // Save bot message immediately with streaming status
        Task {
            do {
                try await databaseManager.saveMessage(botMessage)
            } catch {
                print("Failed to save initial bot message: \(error)")
            }
        }
        
        do {
            // Use current LLM service
            guard let service = currentService else {
                throw LLMServiceError.notConfigured
            }
            
            // Pass chat history without the current user message (it was just added)
            let historyWithoutCurrent = messages.dropLast()
            let stream = try await service.sendMessage(
                content: userMessage.content,
                images: userMessage.imageData != nil ? [userMessage.imageData!] : [],
                chatHistory: Array(historyWithoutCurrent)
            )
            
            // Process stream
            var isFirstChunk = true
            for try await chunk in stream {
                botMessage.appendContent(chunk)
                
                // Add message to array on first chunk
                if isFirstChunk {
                    isFirstChunk = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        messages.append(botMessage)
                        isTyping = false  // Hide typing indicator when content starts
                    }
                }
                
                updateStreamingMessage(botMessage)
            }
            // Check if task was cancelled
            if Task.isCancelled {
                return
            }
            
            // If no content was received, still add the message
            if messages.firstIndex(where: { $0.id == botMessage.id }) == nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    messages.append(botMessage)
                    isTyping = false
                }
            }
            
            // Mark as complete - get the latest version from array
            if let index = messages.firstIndex(where: { $0.id == botMessage.id }) {
                messages[index].setStatus(.sent)
                botMessage = messages[index]
            }
            finalizeMessage(botMessage)
            
        } catch {
            // Handle error
            self.error = error
            
            // If message wasn't added yet, add it now
            if messages.firstIndex(where: { $0.id == botMessage.id }) == nil {
                botMessage.markAsFailed(error: MessageError(
                    code: "llm_error",
                    message: error.localizedDescription
                ))
                withAnimation(.easeInOut(duration: 0.2)) {
                    messages.append(botMessage)
                    isTyping = false
                }
            } else {
                // Update message in array
                if let index = messages.firstIndex(where: { $0.id == botMessage.id }) {
                    messages[index].markAsFailed(error: MessageError(
                        code: "llm_error",
                        message: error.localizedDescription
                    ))
                    botMessage = messages[index]
                }
            }
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
    
    /// Reset the scroll to bottom flag
    func resetScrollToBottom() {
        shouldScrollToBottom = false
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
        
        // Save to database - use updateMessage since the initial message was already saved
        Task {
            do {
                try await databaseManager.updateMessage(message)
            } catch {
                print("Failed to update bot message: \(error)")
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
    
    /// Load available provider configurations
    private func loadAvailableProviders() {
        availableProviders = providerConfigurations.filter { config in
            KeychainManager.hasAPIKey(for: config.provider)
        }
    }
    
    /// Setup the default service on initialization
    private func setupDefaultService() {
        if forceUseMockService {
            currentService = MockLLMService(provider: defaultProvider)
            return
        }
        
        // Try to use the default configuration
        if let defaultServiceInfo = LLMServiceFactory.getDefaultService() {
            currentService = defaultServiceInfo.service
            currentProviderId = defaultServiceInfo.configId
        } else {
            // Fallback to mock service
            currentService = MockLLMService(provider: defaultProvider)
        }
    }
    
    /// Switch to a different provider configuration
    func switchToProvider(_ configId: UUID) {
        guard let config = LLMServiceFactory.getConfiguration(by: configId) else {
            print("Configuration not found: \(configId)")
            return
        }
        
        // Cancel any ongoing streaming
        streamingTask?.cancel()
        
        // Create new service
        if let service = LLMServiceFactory.createService(for: config) {
            currentService = service
            currentProviderId = configId
        } else {
            print("Failed to create service for configuration: \(config.friendlyName)")
        }
    }
    
    /// Get the current provider configuration
    var currentProviderConfig: ProviderConfiguration? {
        guard let configId = currentProviderId else { return nil }
        return providerConfigurations.first { $0.id == configId }
    }
    
    /// Setup observation of provider changes
    private func setupProviderObservation() {
        // Observe provider changes
        Defaults.publisher(.defaultLLMProvider)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleProviderChange()
                }
            }
            .store(in: &cancellables)
        
        // Observe configuration status changes
        Publishers.CombineLatest4(
            Defaults.publisher(.hasConfiguredOpenAI),
            Defaults.publisher(.hasConfiguredAnthropic),
            Defaults.publisher(.hasConfiguredGoogleAI),
            Defaults.publisher(.hasConfiguredLocalModel)
        )
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleConfigurationChange()
            }
        }
        .store(in: &cancellables)
        
        // Observe model selection changes
        Publishers.CombineLatest3(
            Defaults.publisher(.selectedOpenAIModel),
            Defaults.publisher(.selectedAnthropicModel),
            Defaults.publisher(.selectedGoogleModel)
        )
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleModelChange()
            }
        }
        .store(in: &cancellables)
    }
    
    /// Handle provider changes
    private func handleProviderChange() {
        // Cancel any ongoing streaming
        streamingTask?.cancel()
        
        // Reload available providers
        loadAvailableProviders()
        
        // If current provider is no longer available, switch to default
        if let currentId = currentProviderId,
           !availableProviders.contains(where: { $0.id == currentId }) {
            setupDefaultService()
        }
    }
    
    /// Handle configuration status changes
    private func handleConfigurationChange() {
        // Reload available providers
        loadAvailableProviders()
        
        // If current configuration changed, reload it
        if let currentId = currentProviderId,
           let config = providerConfigurations.first(where: { $0.id == currentId }) {
            if let service = LLMServiceFactory.createService(for: config) {
                currentService = service
            } else {
                // Configuration is no longer valid, switch to default
                setupDefaultService()
            }
        }
    }
    
    /// Handle model selection changes
    private func handleModelChange() {
        // Model changes don't require service recreation
        // The service will use the updated model on the next request
    }
    
    /// Get the default model for the current provider
    private func getDefaultModel() -> String {
        switch defaultProvider {
        case .openai:
            return selectedOpenAIModel
        case .anthropic:
            return selectedAnthropicModel
        case .google:
            return selectedGoogleModel
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
    
    // MARK: - Private Helper Methods
    
    /// Generate a chat title from the first message
    private func generateChatTitle(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If content is short enough, use it as is
        if trimmed.count <= 30 {
            return trimmed
        }
        
        // Otherwise, truncate and add ellipsis
        let truncated = String(trimmed.prefix(27))
        return "\(truncated)..."
    }
}