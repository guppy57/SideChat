import Testing
import Foundation
@testable import SideChat

// MARK: - Chat View Model Tests

@Suite("ChatViewModel Tests")
struct ChatViewModelTests {
    
    // MARK: - Initialization Tests
    
    @Test("ChatViewModel initializes with correct default values")
    @MainActor
    func testInitialization() async {
        let viewModel = ChatViewModel()
        
        // Wait for initial load
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(viewModel.chatId != UUID())
        #expect(viewModel.messages.isEmpty == false) // Has mock messages
        #expect(viewModel.isTyping == false)
        #expect(viewModel.currentStreamingMessage == nil)
        #expect(viewModel.error == nil)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("ChatViewModel initializes with provided chat ID")
    @MainActor
    func testInitializationWithChatId() {
        let chatId = UUID()
        let viewModel = ChatViewModel(chatId: chatId)
        
        #expect(viewModel.chatId == chatId)
    }
    
    // MARK: - Message Management Tests
    
    @Test("Send message creates user message")
    @MainActor
    func testSendMessageCreatesUserMessage() async {
        let viewModel = ChatViewModel()
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
    func testSendEmptyMessage() {
        let viewModel = ChatViewModel()
        let initialCount = viewModel.messages.count
        
        viewModel.sendMessage(content: "   ")
        
        #expect(viewModel.messages.count == initialCount)
    }
    
    @Test("Send message with images")
    @MainActor
    func testSendMessageWithImages() async {
        let viewModel = ChatViewModel()
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
        let viewModel = ChatViewModel()
        
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
        let viewModel = ChatViewModel()
        
        // Wait for initial load
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        guard let firstMessage = viewModel.messages.first else {
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
        let viewModel = ChatViewModel()
        
        // Wait for initial load
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        guard let messageToDelete = viewModel.messages.first else {
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
        let viewModel = ChatViewModel()
        
        // Wait for initial load
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(viewModel.hasMessages == true)
        #expect(viewModel.lastMessage != nil)
        
        // Test with fresh view model that might have no messages
        // (This test depends on mock data being loaded)
    }
    
    @Test("Is waiting for response detects user message")
    @MainActor
    func testIsWaitingForResponse() async {
        let viewModel = ChatViewModel()
        
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
        let viewModel = ChatViewModel()
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
        let viewModel = ChatViewModel()
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
        let viewModel = ChatViewModel()
        
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
    
    @Test("Full message flow works correctly")
    @MainActor
    func testFullMessageFlow() async {
        let viewModel = ChatViewModel()
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
            #expect(botMsg.status == .sent)
        }
    }
}

// MARK: - Performance Tests

@Suite("ChatViewModel Performance Tests")
struct ChatViewModelPerformanceTests {
    
    @Test("Handle large message history efficiently")
    @MainActor
    func testLargeMessageHistory() async {
        let viewModel = ChatViewModel()
        
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