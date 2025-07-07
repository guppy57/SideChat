import XCTest
import SQLite
@testable import SideChat

final class DatabasePerformanceTests: XCTestCase {
    
    var databaseManager: DatabaseManager!
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
        try DatabaseSchema.createTables(db: testConnection)
        
        // Set up test data
        databaseManager = DatabaseManager.shared
        optimizer = DatabasePerformanceOptimizer.shared
        
        // Wait for database initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    override func tearDown() async throws {
        // Clean up test database
        testConnection = nil
        
        if let testPath = testDatabasePath,
           FileManager.default.fileExists(atPath: testPath) {
            try FileManager.default.removeItem(atPath: testPath)
        }
        
        testDatabasePath = nil
        databaseManager = nil
        optimizer = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Pagination Tests
    
    func testChatPagination() async throws {
        // Create test data
        let testChats = createTestChats(count: 100)
        _ = try await databaseManager.batchSaveChats(testChats)
        
        // Test pagination
        let options = DatabasePerformanceOptimizer.PaginationOptions(
            offset: 0,
            limit: 20,
            sortOrder: .newest
        )
        
        let result = try await databaseManager.loadChatsPaginated(options: options)
        
        XCTAssertEqual(result.items.count, 20, "Should return 20 items")
        XCTAssertEqual(result.totalCount, 100, "Should have total count of 100")
        XCTAssertTrue(result.hasMore, "Should have more items")
        XCTAssertEqual(result.nextOffset, 20, "Next offset should be 20")
    }
    
    func testMessagePagination() async throws {
        // Create test chat and messages
        let testChat = createTestChat()
        try await databaseManager.saveChat(testChat)
        
        let testMessages = createTestMessages(for: testChat.id, count: 150)
        _ = try await databaseManager.batchSaveMessages(testMessages)
        
        // Test pagination
        let options = DatabasePerformanceOptimizer.PaginationOptions(
            offset: 0,
            limit: 50,
            sortOrder: .newest
        )
        
        let result = try await databaseManager.loadMessagesPaginated(
            for: testChat.id,
            options: options
        )
        
        XCTAssertEqual(result.items.count, 50, "Should return 50 items")
        XCTAssertEqual(result.totalCount, 150, "Should have total count of 150")
        XCTAssertTrue(result.hasMore, "Should have more items")
        XCTAssertEqual(result.nextOffset, 50, "Next offset should be 50")
    }
    
    func testPaginationPerformance() async throws {
        // Create large dataset
        let testChats = createTestChats(count: 1000)
        _ = try await databaseManager.batchSaveChats(testChats)
        
        // Measure pagination performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let options = DatabasePerformanceOptimizer.PaginationOptions(
            offset: 500,
            limit: 50,
            sortOrder: .newest
        )
        
        _ = try await databaseManager.loadChatsPaginated(options: options)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
        
        XCTAssertLessThan(executionTime, 100, "Pagination should complete in under 100ms")
    }
    
    // MARK: - Batch Operations Tests
    
    func testBatchInsertChats() async throws {
        let testChats = createTestChats(count: 500)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await databaseManager.batchSaveChats(testChats)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = (endTime - startTime) * 1000
        
        XCTAssertEqual(result.successCount, 500, "All chats should be inserted successfully")
        XCTAssertEqual(result.failureCount, 0, "No failures should occur")
        XCTAssertLessThan(executionTime, 1000, "Batch insert should complete in under 1 second")
        
        // Verify data was actually inserted
        let allChats = try await databaseManager.loadAllChats()
        XCTAssertEqual(allChats.count, 500, "All chats should be in database")
    }
    
    func testBatchInsertMessages() async throws {
        // Create test chat first
        let testChat = createTestChat()
        try await databaseManager.saveChat(testChat)
        
        let testMessages = createTestMessages(for: testChat.id, count: 1000)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await databaseManager.batchSaveMessages(testMessages)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = (endTime - startTime) * 1000
        
        XCTAssertEqual(result.successCount, 1000, "All messages should be inserted successfully")
        XCTAssertEqual(result.failureCount, 0, "No failures should occur")
        XCTAssertLessThan(executionTime, 2000, "Batch insert should complete in under 2 seconds")
        
        // Verify data was actually inserted
        let allMessages = try await databaseManager.loadMessages(for: testChat.id)
        XCTAssertEqual(allMessages.count, 1000, "All messages should be in database")
    }
    
    func testBatchDeleteMessages() async throws {
        // Create test data
        let testChat = createTestChat()
        try await databaseManager.saveChat(testChat)
        
        let testMessages = createTestMessages(for: testChat.id, count: 200)
        _ = try await databaseManager.batchSaveMessages(testMessages)
        
        // Delete half of the messages
        let messagesToDelete = Array(testMessages.prefix(100)).map { $0.id }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await databaseManager.batchDeleteMessages(messagesToDelete)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = (endTime - startTime) * 1000
        
        XCTAssertEqual(result.successCount, 100, "All targeted messages should be deleted")
        XCTAssertEqual(result.failureCount, 0, "No failures should occur")
        XCTAssertLessThan(executionTime, 500, "Batch delete should complete in under 500ms")
        
        // Verify deletion
        let remainingMessages = try await databaseManager.loadMessages(for: testChat.id)
        XCTAssertEqual(remainingMessages.count, 100, "Only 100 messages should remain")
    }
    
    // MARK: - Search and Filtering Tests
    
    func testOptimizedChatSearch() async throws {
        // Create test data with searchable content
        let testChats = createTestChatsWithSearchableContent()
        _ = try await databaseManager.batchSaveChats(testChats)
        
        let filters = ChatFilters(
            provider: .openai,
            isArchived: false,
            searchTerm: "machine learning"
        )
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await databaseManager.loadChatsPaginated(filters: filters)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = (endTime - startTime) * 1000
        
        XCTAssertGreaterThan(result.items.count, 0, "Should find matching chats")
        XCTAssertLessThan(executionTime, 50, "Search should complete in under 50ms")
        
        // Verify search results are correct
        for chat in result.items {
            XCTAssertEqual(chat.llmProvider, .openai, "Should only return OpenAI chats")
            XCTAssertFalse(chat.isArchived, "Should only return non-archived chats")
            XCTAssertTrue(
                chat.title.lowercased().contains("machine learning") ||
                chat.lastMessagePreview?.lowercased().contains("machine learning") == true,
                "Should contain search term"
            )
        }
    }
    
    func testOptimizedMessageSearch() async throws {
        // Create test data
        let testChat = createTestChat()
        try await databaseManager.saveChat(testChat)
        
        let testMessages = createTestMessagesWithSearchableContent(for: testChat.id)
        _ = try await databaseManager.batchSaveMessages(testMessages)
        
        let filters = MessageFilters(
            isUser: true,
            searchTerm: "swift programming"
        )
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await databaseManager.loadMessagesPaginated(
            for: testChat.id,
            filters: filters
        )
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = (endTime - startTime) * 1000
        
        XCTAssertGreaterThan(result.items.count, 0, "Should find matching messages")
        XCTAssertLessThan(executionTime, 75, "Search should complete in under 75ms")
        
        // Verify search results are correct
        for message in result.items {
            XCTAssertTrue(message.isUser, "Should only return user messages")
            XCTAssertTrue(
                message.content.lowercased().contains("swift programming"),
                "Should contain search term"
            )
        }
    }
    
    // MARK: - Archival and Cleanup Tests
    
    func testDataArchival() async throws {
        // Create old test data
        let oldDate = Date().addingTimeInterval(-100 * 24 * 60 * 60) // 100 days ago
        let testChats = createTestChatsWithDate(date: oldDate, count: 50)
        _ = try await databaseManager.batchSaveChats(testChats)
        
        // Create messages for each chat
        for chat in testChats {
            let messages = createTestMessagesWithDate(for: chat.id, date: oldDate, count: 20)
            _ = try await databaseManager.batchSaveMessages(messages)
        }
        
        let options = DatabasePerformanceOptimizer.ArchivalOptions(
            olderThanDays: 90,
            keepRecentMessagesCount: 5,
            deleteImages: true,
            compressContent: true
        )
        
        let result = try await databaseManager.archiveOldData(options: options)
        
        XCTAssertEqual(result.archivedChats, 50, "Should archive all old chats")
        XCTAssertGreaterThan(result.archivedMessages, 0, "Should archive some messages")
        XCTAssertGreaterThan(result.freedSpaceMB, 0, "Should free up some space")
        XCTAssertLessThan(result.executionTimeMs, 2000, "Archival should complete in under 2 seconds")
    }
    
    func testCleanupOrphanedData() async throws {
        // Create test data with orphaned messages
        let testChat = createTestChat()
        try await databaseManager.saveChat(testChat)
        
        let testMessages = createTestMessages(for: testChat.id, count: 50)
        _ = try await databaseManager.batchSaveMessages(testMessages)
        
        // Delete the chat but leave messages (creating orphans)
        try await databaseManager.deleteChat(id: testChat.id)
        
        let result = try await databaseManager.cleanupDatabase()
        
        XCTAssertEqual(result.deletedRecords, 50, "Should delete all orphaned messages")
        XCTAssertGreaterThan(result.freedSpaceMB, 0, "Should free up space")
        XCTAssertLessThan(result.executionTimeMs, 1000, "Cleanup should complete in under 1 second")
    }
    
    // MARK: - Performance Metrics Tests
    
    func testPerformanceMetrics() async throws {
        // Create test data
        let testChats = createTestChats(count: 100)
        _ = try await databaseManager.batchSaveChats(testChats)
        
        let metrics = try await databaseManager.getPerformanceMetrics()
        
        XCTAssertEqual(metrics.chatCount, 100, "Should count all chats")
        XCTAssertGreaterThan(metrics.databaseSizeMB, 0, "Database should have some size")
        XCTAssertGreaterThan(metrics.indexCount, 0, "Should have indexes")
        XCTAssertLessThan(metrics.averageChatQueryTimeMs, 100, "Query time should be reasonable")
        XCTAssertLessThan(metrics.fragmentationLevel, 50, "Fragmentation should be reasonable")
    }
    
    func testDatabaseOptimization() async throws {
        // Create test data to fragment the database
        let testChats = createTestChats(count: 200)
        _ = try await databaseManager.batchSaveChats(testChats)
        
        // Delete some data to create fragmentation
        let chatsToDelete = Array(testChats.prefix(100)).map { $0.id }
        for chatId in chatsToDelete {
            try await databaseManager.deleteChat(id: chatId)
        }
        
        let metricsBeforeOptimization = try await databaseManager.getPerformanceMetrics()
        
        // Run optimization
        try await databaseManager.optimizeForPerformance()
        
        let metricsAfterOptimization = try await databaseManager.getPerformanceMetrics()
        
        // Optimization should reduce fragmentation
        XCTAssertLessThanOrEqual(
            metricsAfterOptimization.fragmentationLevel,
            metricsBeforeOptimization.fragmentationLevel,
            "Optimization should reduce or maintain fragmentation level"
        )
    }
    
    // MARK: - Stress Tests
    
    func testLargeDatasetPerformance() async throws {
        // Create a large dataset
        let testChats = createTestChats(count: 1000)
        
        // Measure batch insert performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await databaseManager.batchSaveChats(testChats)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let insertTime = (endTime - startTime) * 1000
        
        XCTAssertEqual(result.successCount, 1000, "All chats should be inserted")
        XCTAssertLessThan(insertTime, 5000, "Large insert should complete in under 5 seconds")
        
        // Measure query performance on large dataset
        let queryStartTime = CFAbsoluteTimeGetCurrent()
        let paginatedResult = try await databaseManager.loadChatsPaginated()
        let queryEndTime = CFAbsoluteTimeGetCurrent()
        
        let queryTime = (queryEndTime - queryStartTime) * 1000
        
        XCTAssertGreaterThan(paginatedResult.items.count, 0, "Should return results")
        XCTAssertLessThan(queryTime, 200, "Query on large dataset should complete in under 200ms")
    }
    
    // MARK: - Helper Methods
    
    private func createTestChats(count: Int) -> [Chat] {
        return (0..<count).map { i in
            Chat(
                id: UUID(),
                title: "Test Chat \(i)",
                createdAt: Date().addingTimeInterval(-Double(i * 60)), // Spread over time
                updatedAt: Date().addingTimeInterval(-Double(i * 30)),
                llmProvider: [.openai, .anthropic, .google].randomElement()!,
                modelName: "test-model",
                isArchived: i % 10 == 0, // Every 10th chat is archived
                messageCount: Int.random(in: 1...50),
                lastMessagePreview: "Preview for chat \(i)"
            )
        }
    }
    
    private func createTestChat() -> Chat {
        return Chat(
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
    }
    
    private func createTestMessages(for chatId: UUID, count: Int) -> [Message] {
        return (0..<count).map { i in
            Message(
                id: UUID(),
                chatId: chatId,
                content: "Test message \(i)",
                isUser: i % 2 == 0,
                timestamp: Date().addingTimeInterval(-Double(i * 10)),
                imageData: nil,
                metadata: nil,
                status: .sent,
                editedAt: nil
            )
        }
    }
    
    private func createTestChatsWithSearchableContent() -> [Chat] {
        let searchTerms = [
            "machine learning", "artificial intelligence", "swift programming",
            "database optimization", "performance testing", "data structures"
        ]
        
        return (0..<100).map { i in
            let searchTerm = searchTerms[i % searchTerms.count]
            return Chat(
                id: UUID(),
                title: "Chat about \(searchTerm) \(i)",
                createdAt: Date(),
                updatedAt: Date(),
                llmProvider: [.openai, .anthropic, .google].randomElement()!,
                modelName: "test-model",
                isArchived: i % 20 == 0,
                messageCount: 10,
                lastMessagePreview: "Discussion about \(searchTerm)"
            )
        }
    }
    
    private func createTestMessagesWithSearchableContent(for chatId: UUID) -> [Message] {
        let searchTerms = [
            "swift programming", "ios development", "database queries",
            "performance optimization", "unit testing", "code review"
        ]
        
        return (0..<100).map { i in
            let searchTerm = searchTerms[i % searchTerms.count]
            return Message(
                id: UUID(),
                chatId: chatId,
                content: "Message about \(searchTerm) number \(i)",
                isUser: i % 2 == 0,
                timestamp: Date().addingTimeInterval(-Double(i * 10)),
                imageData: nil,
                metadata: nil,
                status: .sent,
                editedAt: nil
            )
        }
    }
    
    private func createTestChatsWithDate(date: Date, count: Int) -> [Chat] {
        return (0..<count).map { i in
            Chat(
                id: UUID(),
                title: "Old Chat \(i)",
                createdAt: date.addingTimeInterval(-Double(i * 60)),
                updatedAt: date.addingTimeInterval(-Double(i * 30)),
                llmProvider: .openai,
                modelName: "gpt-4",
                isArchived: false,
                messageCount: 20,
                lastMessagePreview: "Old message preview"
            )
        }
    }
    
    private func createTestMessagesWithDate(for chatId: UUID, date: Date, count: Int) -> [Message] {
        return (0..<count).map { i in
            Message(
                id: UUID(),
                chatId: chatId,
                content: "Old message \(i)",
                isUser: i % 2 == 0,
                timestamp: date.addingTimeInterval(-Double(i * 10)),
                imageData: Data(repeating: 0, count: 1024), // 1KB of dummy image data
                metadata: nil,
                status: .sent,
                editedAt: nil
            )
        }
    }
}