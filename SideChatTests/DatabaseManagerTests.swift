import XCTest
import SQLite
@testable import SideChat

final class DatabaseManagerTests: XCTestCase {
    
    var databaseManager: DatabaseManager!
    var testDatabasePath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Configure SQLite's date formatter for tests to match app configuration
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // Create a temporary database for testing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_sidechat_\(UUID().uuidString).db")
        testDatabasePath = tempURL.path
        
        // Remove existing test database if it exists
        if FileManager.default.fileExists(atPath: testDatabasePath) {
            try FileManager.default.removeItem(atPath: testDatabasePath)
        }
        
        // Create a test database manager instance with custom path
        databaseManager = await DatabaseManager.forTesting(databasePath: testDatabasePath)
        
        // Initialize the database
        await databaseManager.initialize()
        
        // Wait for database initialization to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    override func tearDown() async throws {
        // Clean up test database
        if let testPath = testDatabasePath,
           FileManager.default.fileExists(atPath: testPath) {
            try FileManager.default.removeItem(atPath: testPath)
        }
        
        databaseManager = nil
        testDatabasePath = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Chat Operations Tests
    
    func testSaveAndLoadChat() async throws {
        let testChat = Chat(
            id: UUID(),
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        // Save chat
        try await databaseManager.saveChat(testChat)
        
        // Load chat
        let loadedChat = try await databaseManager.loadChat(id: testChat.id)
        
        XCTAssertNotNil(loadedChat)
        XCTAssertEqual(loadedChat?.id, testChat.id)
        XCTAssertEqual(loadedChat?.title, testChat.title)
        XCTAssertEqual(loadedChat?.llmProvider, testChat.llmProvider)
        XCTAssertEqual(loadedChat?.modelName, testChat.modelName)
        XCTAssertEqual(loadedChat?.isArchived, testChat.isArchived)
    }
    
    func testLoadNonExistentChat() async throws {
        let nonExistentId = UUID()
        let loadedChat = try await databaseManager.loadChat(id: nonExistentId)
        XCTAssertNil(loadedChat)
    }
    
    func testLoadAllChats() async throws {
        let chat1 = Chat(
            id: UUID(),
            title: "Chat 1",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        let chat2 = Chat(
            id: UUID(),
            title: "Chat 2",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .anthropic,
            modelName: "claude-3-sonnet",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        // Save chats
        try await databaseManager.saveChat(chat1)
        try await databaseManager.saveChat(chat2)
        
        // Load all chats
        let allChats = try await databaseManager.loadAllChats()
        
        XCTAssertEqual(allChats.count, 2)
        XCTAssertTrue(allChats.contains { $0.id == chat1.id })
        XCTAssertTrue(allChats.contains { $0.id == chat2.id })
    }
    
    func testDeleteChat() async throws {
        let testChat = Chat(
            id: UUID(),
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        // Save chat
        try await databaseManager.saveChat(testChat)
        
        // Verify chat exists
        let loadedChat = try await databaseManager.loadChat(id: testChat.id)
        XCTAssertNotNil(loadedChat)
        
        // Delete chat
        try await databaseManager.deleteChat(id: testChat.id)
        
        // Verify chat is deleted
        let deletedChat = try await databaseManager.loadChat(id: testChat.id)
        XCTAssertNil(deletedChat)
    }
    
    func testSearchChats() async throws {
        let chat1 = Chat(
            id: UUID(),
            title: "Machine Learning Discussion",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: "Let's talk about neural networks"
        )
        
        let chat2 = Chat(
            id: UUID(),
            title: "Cooking Recipes",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .anthropic,
            modelName: "claude-3-sonnet",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: "How to make pasta"
        )
        
        // Save chats
        try await databaseManager.saveChat(chat1)
        try await databaseManager.saveChat(chat2)
        
        // Search for "machine"
        let searchResults = try await databaseManager.searchChats(query: "machine")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.id, chat1.id)
        
        // Search for "cooking"
        let cookingResults = try await databaseManager.searchChats(query: "cooking")
        XCTAssertEqual(cookingResults.count, 1)
        XCTAssertEqual(cookingResults.first?.id, chat2.id)
    }
    
    func testGetChatsByProvider() async throws {
        let openAIChat = Chat(
            id: UUID(),
            title: "OpenAI Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        let anthropicChat = Chat(
            id: UUID(),
            title: "Anthropic Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .anthropic,
            modelName: "claude-3-sonnet",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        // Save chats
        try await databaseManager.saveChat(openAIChat)
        try await databaseManager.saveChat(anthropicChat)
        
        // Get OpenAI chats
        let openAIChats = try await databaseManager.getChatsByProvider(.openai)
        XCTAssertEqual(openAIChats.count, 1)
        XCTAssertEqual(openAIChats.first?.id, openAIChat.id)
        
        // Get Anthropic chats
        let anthropicChats = try await databaseManager.getChatsByProvider(.anthropic)
        XCTAssertEqual(anthropicChats.count, 1)
        XCTAssertEqual(anthropicChats.first?.id, anthropicChat.id)
    }
    
    // MARK: - Message Operations Tests
    
    func testSaveAndLoadMessage() async throws {
        let testChat = Chat(
            id: UUID(),
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        // Save chat first
        try await databaseManager.saveChat(testChat)
        
        let testMessage = Message(
            id: UUID(),
            chatId: testChat.id,
            content: "Hello, world!",
            isUser: true,
            timestamp: Date(),
            imageData: nil,
            metadata: MessageMetadata(
                model: "gpt-4",
                provider: .openai,
                responseTime: 1.5,
                promptTokens: 10,
                responseTokens: 20,
                totalTokens: 30
            ),
            status: .sent,
            editedAt: nil
        )
        
        // Save message
        try await databaseManager.saveMessage(testMessage)
        
        // Load messages for chat
        let loadedMessages = try await databaseManager.loadMessages(for: testChat.id)
        
        XCTAssertEqual(loadedMessages.count, 1)
        let loadedMessage = loadedMessages.first!
        XCTAssertEqual(loadedMessage.id, testMessage.id)
        XCTAssertEqual(loadedMessage.content, testMessage.content)
        XCTAssertEqual(loadedMessage.isUser, testMessage.isUser)
        XCTAssertEqual(loadedMessage.status, testMessage.status)
        XCTAssertEqual(loadedMessage.metadata?.model, testMessage.metadata?.model)
        XCTAssertEqual(loadedMessage.metadata?.provider, testMessage.metadata?.provider)
    }
    
    func testDeleteMessage() async throws {
        let testChat = Chat(
            id: UUID(),
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        // Save chat first
        try await databaseManager.saveChat(testChat)
        
        let testMessage = Message(
            id: UUID(),
            chatId: testChat.id,
            content: "Hello, world!",
            isUser: true,
            timestamp: Date(),
            imageData: nil,
            metadata: nil,
            status: .sent,
            editedAt: nil
        )
        
        // Save message
        try await databaseManager.saveMessage(testMessage)
        
        // Verify message exists
        let messagesBeforeDelete = try await databaseManager.loadMessages(for: testChat.id)
        XCTAssertEqual(messagesBeforeDelete.count, 1)
        
        // Delete message
        try await databaseManager.deleteMessage(id: testMessage.id)
        
        // Verify message is deleted
        let messagesAfterDelete = try await databaseManager.loadMessages(for: testChat.id)
        XCTAssertEqual(messagesAfterDelete.count, 0)
    }
    
    func testSearchMessages() async throws {
        let testChat = Chat(
            id: UUID(),
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        // Save chat first
        try await databaseManager.saveChat(testChat)
        
        let message1 = Message(
            id: UUID(),
            chatId: testChat.id,
            content: "Hello, how are you?",
            isUser: true,
            timestamp: Date(),
            imageData: nil,
            metadata: nil,
            status: .sent,
            editedAt: nil
        )
        
        let message2 = Message(
            id: UUID(),
            chatId: testChat.id,
            content: "I'm doing well, thanks for asking!",
            isUser: false,
            timestamp: Date(),
            imageData: nil,
            metadata: nil,
            status: .sent,
            editedAt: nil
        )
        
        // Save messages
        try await databaseManager.saveMessage(message1)
        try await databaseManager.saveMessage(message2)
        
        // Search for "hello"
        let searchResults = try await databaseManager.searchMessages(query: "hello")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.id, message1.id)
        
        // Search for "well"
        let wellResults = try await databaseManager.searchMessages(query: "well")
        XCTAssertEqual(wellResults.count, 1)
        XCTAssertEqual(wellResults.first?.id, message2.id)
    }
    
    // MARK: - Statistics Tests
    
    func testGetChatStatistics() async throws {
        let chat1 = Chat(
            id: UUID(),
            title: "OpenAI Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        let chat2 = Chat(
            id: UUID(),
            title: "Anthropic Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .anthropic,
            modelName: "claude-3-sonnet",
            isArchived: true,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        // Save chats
        try await databaseManager.saveChat(chat1)
        try await databaseManager.saveChat(chat2)
        
        // Get statistics
        let stats = try await databaseManager.getChatStatistics()
        
        XCTAssertEqual(stats.totalChats, 2)
        XCTAssertEqual(stats.activeCount, 1)
        XCTAssertEqual(stats.archivedCount, 1)
        XCTAssertEqual(stats.chatsByProvider[.openai], 1)
        XCTAssertEqual(stats.chatsByProvider[.anthropic], 1)
    }
    
    // MARK: - Database Maintenance Tests
    
    func testVacuum() async throws {
        // This test just verifies the vacuum operation doesn't throw
        try await databaseManager.vacuum()
    }
    
    func testDeleteAllData() async throws {
        let testChat = Chat(
            id: UUID(),
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        // Save chat
        try await databaseManager.saveChat(testChat)
        
        // Verify chat exists
        let chatsBeforeDelete = try await databaseManager.loadAllChats()
        XCTAssertEqual(chatsBeforeDelete.count, 1)
        
        // Delete all data
        try await databaseManager.deleteAllData()
        
        // Verify all data is deleted
        let chatsAfterDelete = try await databaseManager.loadAllChats()
        XCTAssertEqual(chatsAfterDelete.count, 0)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceLoadAllChats() async throws {
        // Create 100 test chats
        for i in 0..<100 {
            let chat = Chat(
                id: UUID(),
                title: "Test Chat \(i)",
                createdAt: Date(),
                updatedAt: Date(),
                llmProvider: .openai,
                modelName: "gpt-4",
                isArchived: false,
                messageCount: 0,
                lastMessagePreview: nil
            )
            try await databaseManager.saveChat(chat)
        }
        
        // Measure performance of loading all chats
        measure {
            let expectation = expectation(description: "Load all chats")
            Task {
                do {
                    _ = try await databaseManager.loadAllChats()
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to load chats: \(error)")
                }
            }
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testPerformanceSearchChats() async throws {
        // Create 100 test chats with searchable content
        for i in 0..<100 {
            let chat = Chat(
                id: UUID(),
                title: "Test Chat \(i)",
                createdAt: Date(),
                updatedAt: Date(),
                llmProvider: .openai,
                modelName: "gpt-4",
                isArchived: false,
                messageCount: 0,
                lastMessagePreview: "This is a test message number \(i)"
            )
            try await databaseManager.saveChat(chat)
        }
        
        // Measure performance of searching chats
        measure {
            let expectation = expectation(description: "Search chats")
            Task {
                do {
                    _ = try await databaseManager.searchChats(query: "test")
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to search chats: \(error)")
                }
            }
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testDatabaseConnectionError() async throws {
        // This test would require more sophisticated mocking
        // For now, we'll just verify that database operations complete without throwing
        let testChat = Chat(
            id: UUID(),
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        // This should not throw
        try await databaseManager.saveChat(testChat)
        let loadedChat = try await databaseManager.loadChat(id: testChat.id)
        XCTAssertNotNil(loadedChat)
    }
}