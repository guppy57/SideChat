import XCTest
import SQLite
@testable import SideChat

final class FTSManagerTests: XCTestCase {
    
    var db: Connection!
    var ftsManager: FTSManager!
    var testDatabasePath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary database for testing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_fts_\(UUID().uuidString).db")
        testDatabasePath = tempURL.path
        
        // Create database connection
        db = try Connection(testDatabasePath)
        
        // Create tables
        try DatabaseSchema.createTables(db: db)
        
        // Initialize FTS manager
        ftsManager = FTSManager(database: db)
        try await ftsManager.setupFTSTables()
    }
    
    override func tearDown() async throws {
        // Clean up test database
        if let testPath = testDatabasePath,
           FileManager.default.fileExists(atPath: testPath) {
            try FileManager.default.removeItem(atPath: testPath)
        }
        
        db = nil
        ftsManager = nil
        testDatabasePath = nil
        
        try await super.tearDown()
    }
    
    // MARK: - FTS Setup Tests
    
    func testFTSTablesCreation() async throws {
        // Check if FTS tables were created
        let chatsFTSExists = try db.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='chats_fts'"
        ) as! Int64
        
        let messagesFTSExists = try db.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='messages_fts'"
        ) as! Int64
        
        XCTAssertEqual(chatsFTSExists, 1, "chats_fts table should exist")
        XCTAssertEqual(messagesFTSExists, 1, "messages_fts table should exist")
    }
    
    func testFTSHealthCheck() async throws {
        let health = try await ftsManager.checkFTSHealth()
        
        XCTAssertTrue(health.tablesExist, "FTS tables should exist")
        XCTAssertTrue(health.chatsSynchronized, "Chats should be synchronized")
        XCTAssertTrue(health.messagesSynchronized, "Messages should be synchronized")
        XCTAssertFalse(health.isCorrupted, "FTS should not be corrupted")
        XCTAssertTrue(health.isHealthy, "FTS should be healthy")
    }
    
    // MARK: - Chat Search Tests
    
    func testChatSearch() async throws {
        // Insert test chats
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
            modelName: "claude-3",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: "How to make pasta"
        )
        
        // Save chats and sync with FTS
        try await saveChat(chat1)
        try await saveChat(chat2)
        
        // Search for "machine"
        let results = try await ftsManager.searchChats(query: "machine")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, chat1.id.uuidString)
        
        // Search for "cooking"
        let cookingResults = try await ftsManager.searchChats(query: "cooking")
        XCTAssertEqual(cookingResults.count, 1)
        XCTAssertEqual(cookingResults.first, chat2.id.uuidString)
        
        // Search for "neural"
        let neuralResults = try await ftsManager.searchChats(query: "neural")
        XCTAssertEqual(neuralResults.count, 1)
        XCTAssertEqual(neuralResults.first, chat1.id.uuidString)
    }
    
    func testChatSearchWithEmptyQuery() async throws {
        let results = try await ftsManager.searchChats(query: "")
        XCTAssertEqual(results.count, 0, "Empty query should return no results")
        
        let whitespaceResults = try await ftsManager.searchChats(query: "   ")
        XCTAssertEqual(whitespaceResults.count, 0, "Whitespace query should return no results")
    }
    
    // MARK: - Message Search Tests
    
    func testMessageSearch() async throws {
        let chatId = UUID()
        
        // Insert test messages
        let message1 = Message(
            id: UUID(),
            chatId: chatId,
            content: "Hello, how are you doing today?",
            isUser: true,
            timestamp: Date(),
            imageData: nil,
            metadata: nil,
            status: .sent,
            editedAt: nil
        )
        
        let message2 = Message(
            id: UUID(),
            chatId: chatId,
            content: "I'm doing well, thanks for asking!",
            isUser: false,
            timestamp: Date(),
            imageData: nil,
            metadata: nil,
            status: .sent,
            editedAt: nil
        )
        
        // Save messages and sync with FTS
        try await saveMessage(message1)
        try await saveMessage(message2)
        
        // Search for "hello"
        let helloResults = try await ftsManager.searchMessages(query: "hello")
        XCTAssertEqual(helloResults.count, 1)
        XCTAssertEqual(helloResults.first, message1.id.uuidString)
        
        // Search for "thanks"
        let thanksResults = try await ftsManager.searchMessages(query: "thanks")
        XCTAssertEqual(thanksResults.count, 1)
        XCTAssertEqual(thanksResults.first, message2.id.uuidString)
        
        // Search within specific chat
        let chatResults = try await ftsManager.searchMessages(query: "doing", chatId: chatId.uuidString)
        XCTAssertEqual(chatResults.count, 2, "Both messages contain 'doing'")
    }
    
    // MARK: - FTS Synchronization Tests
    
    func testChatSynchronization() async throws {
        let chat = Chat(
            id: UUID(),
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: "Initial preview"
        )
        
        // Save chat
        try await saveChat(chat)
        
        // Update chat title
        try await ftsManager.syncChat(
            chatId: chat.id.uuidString,
            title: "Updated Test Chat",
            lastMessagePreview: "Updated preview"
        )
        
        // Search for updated content
        let results = try await ftsManager.searchChats(query: "Updated")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, chat.id.uuidString)
    }
    
    func testMessageRemoval() async throws {
        let message = Message(
            id: UUID(),
            chatId: UUID(),
            content: "This message will be deleted",
            isUser: true,
            timestamp: Date(),
            imageData: nil,
            metadata: nil,
            status: .sent,
            editedAt: nil
        )
        
        // Save message
        try await saveMessage(message)
        
        // Verify it's searchable
        let beforeRemoval = try await ftsManager.searchMessages(query: "deleted")
        XCTAssertEqual(beforeRemoval.count, 1)
        
        // Remove from FTS
        try await ftsManager.removeMessage(messageId: message.id.uuidString)
        
        // Verify it's no longer searchable
        let afterRemoval = try await ftsManager.searchMessages(query: "deleted")
        XCTAssertEqual(afterRemoval.count, 0)
    }
    
    // MARK: - FTS Rebuild Tests
    
    func testFTSRebuild() async throws {
        // Add some test data
        let chat = Chat(
            id: UUID(),
            title: "Test Chat for Rebuild",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: .openai,
            modelName: "gpt-4",
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: "Test preview"
        )
        
        try await saveChat(chat)
        
        // Rebuild FTS tables
        try await ftsManager.rebuildFTSTables()
        
        // Verify data is still searchable after rebuild
        let results = try await ftsManager.searchChats(query: "Rebuild")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, chat.id.uuidString)
        
        // Check health after rebuild
        let health = try await ftsManager.checkFTSHealth()
        XCTAssertTrue(health.isHealthy, "FTS should be healthy after rebuild")
    }
    
    // MARK: - Helper Methods
    
    private func saveChat(_ chat: Chat) async throws {
        let chats = DatabaseSchema.Tables.chats
        let insert = chats.insert(or: .replace,
            DatabaseSchema.Tables.chatId <- chat.id.uuidString,
            DatabaseSchema.Tables.chatTitle <- chat.title,
            DatabaseSchema.Tables.chatCreatedAt <- chat.createdAt,
            DatabaseSchema.Tables.chatUpdatedAt <- chat.updatedAt,
            DatabaseSchema.Tables.chatLLMProvider <- chat.llmProvider.rawValue,
            DatabaseSchema.Tables.chatModelName <- chat.modelName,
            DatabaseSchema.Tables.chatIsArchived <- chat.isArchived,
            DatabaseSchema.Tables.chatMessageCount <- chat.messageCount,
            DatabaseSchema.Tables.chatLastMessagePreview <- chat.lastMessagePreview
        )
        
        try db.run(insert)
        
        // Sync with FTS
        try await ftsManager.syncChat(
            chatId: chat.id.uuidString,
            title: chat.title,
            lastMessagePreview: chat.lastMessagePreview
        )
    }
    
    private func saveMessage(_ message: Message) async throws {
        let messages = DatabaseSchema.Tables.messages
        let insert = messages.insert(or: .replace,
            DatabaseSchema.Tables.messageId <- message.id.uuidString,
            DatabaseSchema.Tables.messageChatId <- message.chatId.uuidString,
            DatabaseSchema.Tables.messageContent <- message.content,
            DatabaseSchema.Tables.messageIsUser <- message.isUser,
            DatabaseSchema.Tables.messageTimestamp <- message.timestamp,
            DatabaseSchema.Tables.messageImageData <- message.imageData,
            DatabaseSchema.Tables.messageStatus <- message.status.rawValue,
            DatabaseSchema.Tables.messageEditedAt <- message.editedAt,
            DatabaseSchema.Tables.messageModel <- message.metadata?.model,
            DatabaseSchema.Tables.messageProvider <- message.metadata?.provider?.rawValue,
            DatabaseSchema.Tables.messageResponseTime <- message.metadata?.responseTime,
            DatabaseSchema.Tables.messagePromptTokens <- message.metadata?.promptTokens,
            DatabaseSchema.Tables.messageResponseTokens <- message.metadata?.responseTokens,
            DatabaseSchema.Tables.messageTotalTokens <- message.metadata?.totalTokens
        )
        
        try db.run(insert)
        
        // Sync with FTS
        try await ftsManager.syncMessage(
            messageId: message.id.uuidString,
            content: message.content
        )
    }
}