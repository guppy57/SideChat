import XCTest
import SQLite
@testable import SideChat

final class DatabasePerformanceOptimizerTests: XCTestCase {
    
    var testConnection: Connection!
    var testDatabasePath: String!
    var optimizer: DatabasePerformanceOptimizer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary database for testing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_performance.db")
        testDatabasePath = tempURL.path
        
        // Remove existing test database if it exists
        if FileManager.default.fileExists(atPath: testDatabasePath) {
            try FileManager.default.removeItem(atPath: testDatabasePath)
        }
        
        // Create test database connection
        testConnection = try Connection(testDatabasePath)
        
        // Create schema
        try DatabaseSchema.createTables(db: testConnection)
        
        optimizer = DatabasePerformanceOptimizer.shared
    }
    
    override func tearDown() async throws {
        // Clean up test database
        testConnection = nil
        
        if let testPath = testDatabasePath,
           FileManager.default.fileExists(atPath: testPath) {
            try FileManager.default.removeItem(atPath: testPath)
        }
        
        testDatabasePath = nil
        optimizer = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Pagination Tests
    
    func testChatsPagination() throws {
        // Insert test chats
        let testChats = createTestChats(count: 150)
        for chat in testChats {
            try insertTestChat(chat)
        }
        
        // Test pagination
        let options = DatabasePerformanceOptimizer.PaginationOptions(
            offset: 0,
            limit: 50,
            sortOrder: .newest
        )
        
        let result = try optimizer.optimizeChatsQuery(
            db: testConnection,
            options: options,
            filters: ChatFilters()
        )
        
        XCTAssertEqual(result.items.count, 50, "Should return 50 items")
        XCTAssertEqual(result.totalCount, 150, "Should have total count of 150")
        XCTAssertTrue(result.hasMore, "Should have more items")
        XCTAssertEqual(result.nextOffset, 50, "Next offset should be 50")
        
        // Test second page
        let page2Options = DatabasePerformanceOptimizer.PaginationOptions(
            offset: 50,
            limit: 50,
            sortOrder: .newest
        )
        
        let page2Result = try optimizer.optimizeChatsQuery(
            db: testConnection,
            options: page2Options,
            filters: ChatFilters()
        )
        
        XCTAssertEqual(page2Result.items.count, 50, "Second page should have 50 items")
        XCTAssertTrue(page2Result.hasMore, "Should still have more items")
        XCTAssertEqual(page2Result.nextOffset, 100, "Next offset should be 100")
    }
    
    func testMessagesPagination() throws {
        // Create test chat
        let testChat = createTestChats(count: 1)[0]
        try insertTestChat(testChat)
        
        // Insert test messages
        let testMessages = createTestMessages(chatId: testChat.id, count: 200)
        for message in testMessages {
            try insertTestMessage(message)
        }
        
        // Test pagination
        let options = DatabasePerformanceOptimizer.PaginationOptions(
            offset: 0,
            limit: 25,
            sortOrder: .oldest
        )
        
        let result = try optimizer.optimizeMessagesQuery(
            db: testConnection,
            chatId: testChat.id,
            options: options,
            filters: MessageFilters()
        )
        
        XCTAssertEqual(result.items.count, 25, "Should return 25 messages")
        XCTAssertEqual(result.totalCount, 200, "Should have total count of 200")
        XCTAssertTrue(result.hasMore, "Should have more messages")
        XCTAssertEqual(result.nextOffset, 25, "Next offset should be 25")
    }
    
    func testChatsFilteringAndSearch() throws {
        // Insert test chats with different providers
        let openAIChats = createTestChats(count: 30, provider: .openai, titlePrefix: "OpenAI Chat")
        let anthropicChats = createTestChats(count: 20, provider: .anthropic, titlePrefix: "Anthropic Chat")
        
        for chat in openAIChats + anthropicChats {
            try insertTestChat(chat)
        }
        
        // Test provider filtering
        let providerFilter = ChatFilters(provider: .openai)
        let providerResult = try optimizer.optimizeChatsQuery(
            db: testConnection,
            options: .default,
            filters: providerFilter
        )
        
        XCTAssertEqual(providerResult.totalCount, 30, "Should find 30 OpenAI chats")
        XCTAssertTrue(providerResult.items.allSatisfy { $0.llmProvider == .openai })
        
        // Test search filtering
        let searchFilter = ChatFilters(searchTerm: "Anthropic")
        let searchResult = try optimizer.optimizeChatsQuery(
            db: testConnection,
            options: .default,
            filters: searchFilter
        )
        
        XCTAssertEqual(searchResult.totalCount, 20, "Should find 20 Anthropic chats")
        XCTAssertTrue(searchResult.items.allSatisfy { $0.title.contains("Anthropic") })
    }
    
    // MARK: - Batch Operations Tests
    
    func testBatchInsertChats() throws {
        let testChats = createTestChats(count: 500)
        
        let result = try optimizer.batchInsertChats(
            db: testConnection,
            chats: testChats,
            batchSize: 100
        )
        
        XCTAssertEqual(result.successCount, 500, "Should successfully insert all chats")
        XCTAssertEqual(result.failureCount, 0, "Should have no failures")
        XCTAssertTrue(result.isFullSuccess, "Should be a full success")
        XCTAssertLessThan(result.executionTimeMs, 5000, "Should complete in under 5 seconds")
        
        // Verify chats were inserted
        let count = try testConnection.scalar(DatabaseSchema.Tables.chats.count)
        XCTAssertEqual(count, 500, "Should have 500 chats in database")
    }
    
    func testBatchInsertMessages() throws {
        // Create test chat
        let testChat = createTestChats(count: 1)[0]
        try insertTestChat(testChat)
        
        let testMessages = createTestMessages(chatId: testChat.id, count: 1000)
        
        let result = try optimizer.batchInsertMessages(
            db: testConnection,
            messages: testMessages,
            batchSize: 200
        )
        
        XCTAssertEqual(result.successCount, 1000, "Should successfully insert all messages")
        XCTAssertEqual(result.failureCount, 0, "Should have no failures")
        XCTAssertTrue(result.isFullSuccess, "Should be a full success")
        XCTAssertLessThan(result.executionTimeMs, 10000, "Should complete in under 10 seconds")
        
        // Verify messages were inserted
        let count = try testConnection.scalar(DatabaseSchema.Tables.messages.count)
        XCTAssertEqual(count, 1000, "Should have 1000 messages in database")
    }
    
    func testBatchDeleteMessages() throws {
        // Create test data
        let testChat = createTestChats(count: 1)[0]
        try insertTestChat(testChat)
        
        let testMessages = createTestMessages(chatId: testChat.id, count: 100)
        for message in testMessages {
            try insertTestMessage(message)
        }
        
        // Delete half the messages
        let messagesToDelete = Array(testMessages.prefix(50)).map { $0.id }
        
        let result = try optimizer.batchDeleteMessages(
            db: testConnection,
            messageIds: messagesToDelete,
            batchSize: 25
        )
        
        XCTAssertEqual(result.successCount, 50, "Should successfully delete 50 messages")
        XCTAssertEqual(result.failureCount, 0, "Should have no failures")
        
        // Verify messages were deleted
        let remainingCount = try testConnection.scalar(DatabaseSchema.Tables.messages.count)
        XCTAssertEqual(remainingCount, 50, "Should have 50 messages remaining")
    }
    
    // MARK: - Data Archival Tests
    
    func testArchiveOldChatData() throws {
        // Create old and new chats
        let oldDate = Date().addingTimeInterval(-100 * 24 * 60 * 60) // 100 days ago
        let newDate = Date().addingTimeInterval(-10 * 24 * 60 * 60)  // 10 days ago
        
        // Insert old chats
        let oldChats = createTestChats(count: 10, createdDate: oldDate)
        for chat in oldChats {
            try insertTestChat(chat)
            // Add messages to old chats
            let messages = createTestMessages(chatId: chat.id, count: 150, createdDate: oldDate)
            for message in messages {
                try insertTestMessage(message)
            }
        }
        
        // Insert new chats
        let newChats = createTestChats(count: 5, createdDate: newDate)
        for chat in newChats {
            try insertTestChat(chat)
            let messages = createTestMessages(chatId: chat.id, count: 50, createdDate: newDate)
            for message in messages {
                try insertTestMessage(message)
            }
        }
        
        // Archive old data
        let options = DatabasePerformanceOptimizer.ArchivalOptions(
            olderThanDays: 90,
            keepRecentMessagesCount: 50,
            deleteImages: true,
            compressContent: true
        )
        
        let result = try optimizer.archiveOldChatData(db: testConnection, options: options)
        
        XCTAssertEqual(result.archivedChats, 10, "Should archive 10 old chats")
        XCTAssertGreaterThan(result.archivedMessages, 0, "Should archive some messages")
        XCTAssertGreaterThan(result.freedSpaceBytes, 0, "Should free some space")
        
        // Verify old chats are archived
        let archivedCount = try testConnection.scalar(
            DatabaseSchema.Tables.chats.filter(DatabaseSchema.Tables.chatIsArchived == true).count
        )
        XCTAssertEqual(archivedCount, 10, "Should have 10 archived chats")
        
        // Verify new chats are not archived
        let activeCount = try testConnection.scalar(
            DatabaseSchema.Tables.chats.filter(DatabaseSchema.Tables.chatIsArchived == false).count
        )
        XCTAssertEqual(activeCount, 5, "Should have 5 active chats")
    }
    
    func testCleanupOrphanedData() throws {
        // Create orphaned messages
        let orphanedMessages = createTestMessages(chatId: UUID(), count: 25)
        for message in orphanedMessages {
            try insertTestMessage(message)
        }
        
        // Create valid chat with messages
        let validChat = createTestChats(count: 1)[0]
        try insertTestChat(validChat)
        
        let validMessages = createTestMessages(chatId: validChat.id, count: 10)
        for message in validMessages {
            try insertTestMessage(message)
        }
        
        // Clean up orphaned data
        let result = try optimizer.cleanupOrphanedData(db: testConnection)
        
        XCTAssertEqual(result.deletedRecords, 25, "Should delete 25 orphaned messages")
        XCTAssertGreaterThan(result.freedSpaceBytes, 0, "Should free some space")
        
        // Verify only valid messages remain
        let remainingCount = try testConnection.scalar(DatabaseSchema.Tables.messages.count)
        XCTAssertEqual(remainingCount, 10, "Should have 10 valid messages remaining")
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testGetPerformanceMetrics() throws {
        // Create test data
        let testChats = createTestChats(count: 50)
        for chat in testChats {
            try insertTestChat(chat)
            
            let messages = createTestMessages(chatId: chat.id, count: 20)
            for message in messages {
                try insertTestMessage(message)
            }
        }
        
        let metrics = try optimizer.getPerformanceMetrics(db: testConnection)
        
        XCTAssertEqual(metrics.chatCount, 50, "Should have 50 chats")
        XCTAssertEqual(metrics.messageCount, 1000, "Should have 1000 messages")
        XCTAssertGreaterThan(metrics.databaseSizeBytes, 0, "Database should have some size")
        XCTAssertGreaterThan(metrics.indexCount, 0, "Should have indexes")
        XCTAssertLessThan(metrics.averageChatQueryTimeMs, 100, "Chat queries should be fast")
        XCTAssertLessThan(metrics.averageMessageQueryTimeMs, 200, "Message queries should be fast")
        XCTAssertEqual(metrics.averageMessagesPerChat, 20.0, "Should have average of 20 messages per chat")
    }
    
    // MARK: - Performance Benchmarks
    
    func testLargeDatasetPerformance() throws {
        // Create large dataset
        let chats = createTestChats(count: 1000)
        
        // Measure batch insert performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = try optimizer.batchInsertChats(
            db: testConnection,
            chats: chats,
            batchSize: 100
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = (endTime - startTime) * 1000 // Convert to ms
        
        XCTAssertEqual(result.successCount, 1000, "Should insert all chats")
        XCTAssertLessThan(totalTime, 10000, "Should complete large insert in under 10 seconds")
        
        // Test pagination performance on large dataset
        let paginationStart = CFAbsoluteTimeGetCurrent()
        
        let paginatedResult = try optimizer.optimizeChatsQuery(
            db: testConnection,
            options: DatabasePerformanceOptimizer.PaginationOptions(
                offset: 500,
                limit: 50,
                sortOrder: .newest
            )
        )
        
        let paginationEnd = CFAbsoluteTimeGetCurrent()
        let paginationTime = (paginationEnd - paginationStart) * 1000
        
        XCTAssertEqual(paginatedResult.items.count, 50, "Should return 50 items")
        XCTAssertLessThan(paginationTime, 500, "Pagination should complete in under 500ms")
    }
    
    func testConcurrentOperations() throws {
        // Create test data
        let testChats = createTestChats(count: 100)
        for chat in testChats {
            try insertTestChat(chat)
        }
        
        // Test concurrent reads
        let expectation = expectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        let group = DispatchGroup()
        
        for i in 0..<10 {
            group.enter()
            queue.async {
                do {
                    let options = DatabasePerformanceOptimizer.PaginationOptions(
                        offset: i * 10,
                        limit: 10,
                        sortOrder: .newest
                    )
                    
                    let result = try self.optimizer.optimizeChatsQuery(
                        db: self.testConnection,
                        options: options
                    )
                    
                    XCTAssertEqual(result.items.count, 10, "Should return 10 items")
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent operation failed: \(error)")
                }
                group.leave()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestChats(
        count: Int,
        provider: LLMProvider = .openai,
        titlePrefix: String = "Test Chat",
        createdDate: Date = Date()
    ) -> [Chat] {
        return (0..<count).map { i in
            Chat(
                id: UUID(),
                title: "\(titlePrefix) \(i + 1)",
                createdAt: createdDate.addingTimeInterval(TimeInterval(i)),
                updatedAt: createdDate.addingTimeInterval(TimeInterval(i + 60)),
                llmProvider: provider,
                modelName: provider == .openai ? "gpt-4" : "claude-3-sonnet",
                isArchived: false,
                messageCount: 0,
                lastMessagePreview: "This is test chat \(i + 1)"
            )
        }
    }
    
    private func createTestMessages(
        chatId: UUID,
        count: Int,
        createdDate: Date = Date()
    ) -> [Message] {
        return (0..<count).map { i in
            Message(
                id: UUID(),
                chatId: chatId,
                content: "This is test message \(i + 1) with some content to test performance.",
                isUser: i % 2 == 0,
                timestamp: createdDate.addingTimeInterval(TimeInterval(i * 60)),
                imageData: i % 10 == 0 ? Data(repeating: 0xFF, count: 1024) : nil, // Add some image data
                metadata: MessageMetadata(
                    model: "gpt-4",
                    provider: .openai,
                    responseTime: Double.random(in: 0.5...3.0),
                    promptTokens: Int.random(in: 10...100),
                    responseTokens: Int.random(in: 20...200),
                    totalTokens: Int.random(in: 30...300)
                ),
                status: .sent,
                editedAt: nil
            )
        }
    }
    
    private func insertTestChat(_ chat: Chat) throws {
        try testConnection.run(DatabaseSchema.Tables.chats.insert(
            DatabaseSchema.Tables.chatId <- chat.id.uuidString,
            DatabaseSchema.Tables.chatTitle <- chat.title,
            DatabaseSchema.Tables.chatCreatedAt <- chat.createdAt,
            DatabaseSchema.Tables.chatUpdatedAt <- chat.updatedAt,
            DatabaseSchema.Tables.chatLLMProvider <- chat.llmProvider.rawValue,
            DatabaseSchema.Tables.chatModelName <- chat.modelName,
            DatabaseSchema.Tables.chatIsArchived <- chat.isArchived,
            DatabaseSchema.Tables.chatMessageCount <- chat.messageCount,
            DatabaseSchema.Tables.chatLastMessagePreview <- chat.lastMessagePreview
        ))
    }
    
    private func insertTestMessage(_ message: Message) throws {
        try testConnection.run(DatabaseSchema.Tables.messages.insert(
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
        ))
    }
}