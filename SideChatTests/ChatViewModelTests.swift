import Testing
import Foundation
@testable import SideChat

// MARK: - Chat View Model Tests

@Suite("ChatViewModel Tests")
struct ChatViewModelTests {
    
    // MARK: - Test Database Setup
    
    private func createTestDatabaseManager() async -> DatabaseManager {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_chatvm_\(UUID().uuidString).db")
        let testPath = tempURL.path
        
        // Remove existing test database if it exists
        if FileManager.default.fileExists(atPath: testPath) {
            try? FileManager.default.removeItem(atPath: testPath)
        }
        
        let databaseManager = await DatabaseManager.forTesting(databasePath: testPath)
        await databaseManager.initialize()
        
        return databaseManager
    }
    
    // MARK: - Initialization Tests
    
    @Test("ChatViewModel initializes with correct default values")
    @MainActor
    func testInitialization() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        
        // Explicitly load messages since auto-loading is disabled in tests
        await viewModel.loadMessages()
        
        #expect(viewModel.chatId != UUID())
        #expect(viewModel.messages.isEmpty == true) // No messages in test database
        #expect(viewModel.isTyping == false)
        #expect(viewModel.currentStreamingMessage == nil)
        #expect(viewModel.error == nil)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("ChatViewModel initializes with provided chat ID")
    @MainActor
    func testInitializationWithChatId() async {
        let databaseManager = await createTestDatabaseManager()
        let chatId = UUID()
        let viewModel = ChatViewModel(chatId: chatId, databaseManager: databaseManager)
        
        #expect(viewModel.chatId == chatId)
    }
    
    // MARK: - Message Management Tests
    
    @Test("Send message creates user message")
    @MainActor
    func testSendMessageCreatesUserMessage() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        let initialCount = viewModel.messages.count
        
        viewModel.sendMessage(content: "Test message")
        
        // Wait a bit for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(viewModel.messages.count > initialCount)
        
        // Check last messages
        let lastMessages = viewModel.messages.suffix(2)
        if lastMessages.count >= 2 {
            let userMessage = lastMessages[lastMessages.startIndex]
            let botMessage = lastMessages[lastMessages.index(after: lastMessages.startIndex)]
            
            #expect(userMessage.isUser == true)
            #expect(userMessage.content == "Test message")
            #expect(userMessage.status == .sent)
            
            #expect(botMessage.isUser == false)
            #expect(botMessage.status == .streaming || botMessage.status == .sent)
        }
    }
    
    @Test("Send empty message does nothing")
    @MainActor
    func testSendEmptyMessage() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        let initialCount = viewModel.messages.count
        
        viewModel.sendMessage(content: "   ")
        
        #expect(viewModel.messages.count == initialCount)
    }
    
    @Test("Send message with images")
    @MainActor
    func testSendMessageWithImages() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        
        viewModel.sendMessage(content: "Check this image", images: [imageData])
        
        // Wait a bit for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Find the user message
        if let userMessage = viewModel.messages.last(where: { $0.isUser }) {
            #expect(userMessage.content == "Check this image")
            #expect(userMessage.imageData == imageData)
        }
    }
    
    // MARK: - Typing Indicator Tests
    
    @Test("Typing indicator shows during response")
    @MainActor
    func testTypingIndicator() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        
        #expect(viewModel.isTyping == false)
        
        viewModel.sendMessage(content: "Test")
        
        // Wait for typing to start
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(viewModel.isTyping == true)
        
        // Wait for response to complete
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        #expect(viewModel.isTyping == false)
    }
    
    // MARK: - Message Update Tests
    
    @Test("Update message content")
    @MainActor
    func testUpdateMessageContent() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        
        // Explicitly load messages
        await viewModel.loadMessages()
        
        // First, create a message to update
        viewModel.sendMessage(content: "Original message")
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        guard let firstMessage = viewModel.messages.first(where: { $0.isUser }) else {
            Issue.record("No messages to test")
            return
        }
        
        let originalContent = firstMessage.content
        viewModel.updateMessage(id: firstMessage.id, content: "Updated content")
        
        if let updatedMessage = viewModel.messages.first(where: { $0.id == firstMessage.id }) {
            #expect(updatedMessage.content == "Updated content")
            #expect(updatedMessage.content != originalContent)
            #expect(updatedMessage.editedAt != nil)
        }
    }
    
    // MARK: - Message Deletion Tests
    
    @Test("Delete message removes from array")
    @MainActor
    func testDeleteMessage() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        
        // Explicitly load messages
        await viewModel.loadMessages()
        
        // First, create a message to delete
        viewModel.sendMessage(content: "Message to delete")
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        guard let messageToDelete = viewModel.messages.first(where: { $0.isUser }) else {
            Issue.record("No messages to test")
            return
        }
        
        let initialCount = viewModel.messages.count
        viewModel.deleteMessage(id: messageToDelete.id)
        
        #expect(viewModel.messages.count == initialCount - 1)
        #expect(viewModel.messages.contains(where: { $0.id == messageToDelete.id }) == false)
    }
    
    // MARK: - Computed Properties Tests
    
    @Test("Computed properties work correctly")
    @MainActor
    func testComputedProperties() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        
        // Explicitly load messages
        await viewModel.loadMessages()
        
        // Test database starts empty
        #expect(viewModel.hasMessages == false)
        #expect(viewModel.lastMessage == nil)
        
        // Send a message to have some data
        viewModel.sendMessage(content: "Test message")
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(viewModel.hasMessages == true)
        #expect(viewModel.lastMessage != nil)
    }
    
    @Test("Is waiting for response detects user message")
    @MainActor
    func testIsWaitingForResponse() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        
        // Send a message which will create a user message
        viewModel.sendMessage(content: "Test waiting")
        
        // Should be waiting for response initially
        #expect(viewModel.isWaitingForResponse == true)
        
        // Wait for bot response to complete
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Should no longer be waiting
        #expect(viewModel.isWaitingForResponse == false)
    }
    
    // MARK: - Mock Response Tests
    
    @Test("Mock streaming response populates message")
    @MainActor
    func testMockStreamingResponse() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        let initialCount = viewModel.messages.count
        
        viewModel.sendMessage(content: "Test streaming")
        
        // Wait for streaming to complete
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        // Should have added 2 messages (user + bot)
        #expect(viewModel.messages.count == initialCount + 2)
        
        // Check bot message has content
        if let botMessage = viewModel.messages.last {
            #expect(botMessage.isUser == false)
            #expect(botMessage.content.isEmpty == false)
            #expect(botMessage.status == .sent)
        }
    }
    
    @Test("Last message update timestamp changes during streaming")
    @MainActor
    func testLastMessageUpdateTimestamp() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        let initialTimestamp = viewModel.lastMessageUpdate
        
        // Wait a bit to ensure timestamps are different
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        viewModel.sendMessage(content: "Test timestamp update")
        
        // Wait for streaming to start
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Timestamp should have changed
        #expect(viewModel.lastMessageUpdate > initialTimestamp)
        
        let streamingTimestamp = viewModel.lastMessageUpdate
        
        // Wait a bit more for another update
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Should have updated again during streaming
        #expect(viewModel.lastMessageUpdate > streamingTimestamp)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Retry last message functionality")
    @MainActor
    func testRetryLastMessage() async {
        // This test would need a way to simulate failure
        // For now, we'll test that retry doesn't crash on normal messages
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        
        // Send a normal message
        viewModel.sendMessage(content: "Test retry")
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        
        let countBefore = viewModel.messages.count
        
        // Try to retry (should do nothing since no failed message)
        viewModel.retryLastMessage()
        
        // Count should be the same
        #expect(viewModel.messages.count == countBefore)
    }
}

// MARK: - Integration Tests

@Suite("ChatViewModel Integration Tests")
struct ChatViewModelIntegrationTests {
    
    // MARK: - Test Database Setup
    
    private func createTestDatabaseManager() async -> DatabaseManager {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_chatvm_integration_\(UUID().uuidString).db")
        let testPath = tempURL.path
        
        // Remove existing test database if it exists
        if FileManager.default.fileExists(atPath: testPath) {
            try? FileManager.default.removeItem(atPath: testPath)
        }
        
        let databaseManager = await DatabaseManager.forTesting(databasePath: testPath)
        await databaseManager.initialize()
        
        return databaseManager
    }
    
    @Test("Full message flow works correctly")
    @MainActor
    func testFullMessageFlow() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        let initialCount = viewModel.messages.count
        
        // Send a message
        viewModel.sendMessage(content: "Hello, AI!")
        
        // Immediately should have user message
        #expect(viewModel.messages.count > initialCount)
        
        // Wait for bot response to start
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Should be typing
        #expect(viewModel.isTyping == true)
        #expect(viewModel.currentStreamingMessage != nil)
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        
        // Should be complete
        #expect(viewModel.isTyping == false)
        #expect(viewModel.currentStreamingMessage == nil)
        
        // Verify final state
        let addedMessages = viewModel.messages.count - initialCount
        #expect(addedMessages == 2) // User + Bot
        
        if addedMessages >= 2 {
            let userMsg = viewModel.messages[viewModel.messages.count - 2]
            let botMsg = viewModel.messages[viewModel.messages.count - 1]
            
            #expect(userMsg.isUser == true)
            #expect(userMsg.content == "Hello, AI!")
            
            #expect(botMsg.isUser == false)
            #expect(botMsg.content.isEmpty == false)
            #expect(botMsg.status == MessageStatus.sent)
        }
    }
}

// MARK: - Performance Tests

@Suite("ChatViewModel Performance Tests")
struct ChatViewModelPerformanceTests {
    
    // MARK: - Test Database Setup
    
    private func createTestDatabaseManager() async -> DatabaseManager {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_chatvm_perf_\(UUID().uuidString).db")
        let testPath = tempURL.path
        
        // Remove existing test database if it exists
        if FileManager.default.fileExists(atPath: testPath) {
            try? FileManager.default.removeItem(atPath: testPath)
        }
        
        let databaseManager = await DatabaseManager.forTesting(databasePath: testPath)
        await databaseManager.initialize()
        
        return databaseManager
    }
    
    @Test("Handle large message history efficiently")
    @MainActor
    func testLargeMessageHistory() async {
        let databaseManager = await createTestDatabaseManager()
        let viewModel = ChatViewModel(databaseManager: databaseManager)
        
        // Test operations with existing mock data
        let start = Date()
        viewModel.sendMessage(content: "New message")
        let elapsed = Date().timeIntervalSince(start)
        
        #expect(elapsed < 0.1) // Should be fast
        
        // Test sending multiple messages quickly
        for i in 0..<10 {
            viewModel.sendMessage(content: "Bulk message \(i)")
        }
        
        // Should handle multiple messages without issues
        #expect(viewModel.messages.count > 10)
    }
}