import XCTest
import SQLite
@testable import SideChat

final class DatabaseSchemaTests: XCTestCase {
    
    var testConnection: Connection!
    var testDatabasePath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary database for testing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_schema.db")
        testDatabasePath = tempURL.path
        
        // Remove existing test database if it exists
        if FileManager.default.fileExists(atPath: testDatabasePath) {
            try FileManager.default.removeItem(atPath: testDatabasePath)
        }
        
        // Create test database connection
        testConnection = try Connection(testDatabasePath)
    }
    
    override func tearDown() async throws {
        // Clean up test database
        testConnection = nil
        
        if let testPath = testDatabasePath,
           FileManager.default.fileExists(atPath: testPath) {
            try FileManager.default.removeItem(atPath: testPath)
        }
        
        testDatabasePath = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Schema Creation Tests
    
    func testCreateTables() throws {
        // Create tables using DatabaseSchema
        try DatabaseSchema.createTables(db: testConnection)
        
        // Verify chats table exists
        let chatsTableExists = try testConnection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='chats'"
        ) as! Int64 > 0
        XCTAssertTrue(chatsTableExists, "Chats table should exist")
        
        // Verify messages table exists
        let messagesTableExists = try testConnection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='messages'"
        ) as! Int64 > 0
        XCTAssertTrue(messagesTableExists, "Messages table should exist")
        
        // Verify settings table exists
        let settingsTableExists = try testConnection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='settings'"
        ) as! Int64 > 0
        XCTAssertTrue(settingsTableExists, "Settings table should exist")
        
        // Verify chat_stats table exists
        let chatStatsTableExists = try testConnection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='chat_stats'"
        ) as! Int64 > 0
        XCTAssertTrue(chatStatsTableExists, "Chat stats table should exist")
    }
    
    func testCreateFullTextSearchTables() throws {
        // Create all tables
        try DatabaseSchema.createTables(db: testConnection)
        
        // FTS tables removed - verify they don't exist
        let chatsFTSExists = try testConnection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='chats_fts'"
        ) as! Int64 > 0
        XCTAssertFalse(chatsFTSExists, "Chats FTS table should not exist")
        
        let messagesFTSExists = try testConnection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='messages_fts'"
        ) as! Int64 > 0
        XCTAssertFalse(messagesFTSExists, "Messages FTS table should not exist")
    }
    
    func testCreateIndexes() throws {
        // Create tables with indexes
        try DatabaseSchema.createTables(db: testConnection)
        
        // Verify some key indexes exist
        let indexes = [
            "idx_chats_updated_at",
            "idx_chats_is_archived",
            "idx_chats_provider",
            "idx_messages_chat_id",
            "idx_messages_timestamp"
        ]
        
        for indexName in indexes {
            let indexExists = try testConnection.scalar(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name=?",
                indexName
            ) as! Int64 > 0
            XCTAssertTrue(indexExists, "Index \(indexName) should exist")
        }
    }
    
    func testCreateTriggers() throws {
        // Create tables with triggers
        try DatabaseSchema.createTables(db: testConnection)
        
        // Verify triggers exist
        let triggers = [
            "update_chat_stats_insert",
            "update_chat_stats_delete"
        ]
        
        for triggerName in triggers {
            let triggerExists = try testConnection.scalar(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name=?",
                triggerName
            ) as! Int64 > 0
            XCTAssertTrue(triggerExists, "Trigger \(triggerName) should exist")
        }
    }
    
    // MARK: - Schema Validation Tests
    
    func testTableStructure() throws {
        // Create tables
        try DatabaseSchema.createTables(db: testConnection)
        
        // Test chats table structure
        let chatsColumns = try getTableColumns(table: "chats")
        let expectedChatsColumns = [
            "id", "title", "created_at", "updated_at", "llm_provider",
            "model_name", "is_archived", "message_count", "last_message_preview"
        ]
        
        for column in expectedChatsColumns {
            XCTAssertTrue(chatsColumns.contains(column), "Chats table should have column: \(column)")
        }
        
        // Test messages table structure
        let messagesColumns = try getTableColumns(table: "messages")
        let expectedMessagesColumns = [
            "id", "chat_id", "content", "is_user", "timestamp", "image_data",
            "status", "edited_at", "model", "provider", "response_time",
            "prompt_tokens", "response_tokens", "total_tokens"
        ]
        
        for column in expectedMessagesColumns {
            XCTAssertTrue(messagesColumns.contains(column), "Messages table should have column: \(column)")
        }
    }
    
    func testForeignKeyConstraints() throws {
        // Create tables
        try DatabaseSchema.createTables(db: testConnection)
        
        // Enable foreign key constraints
        try testConnection.execute("PRAGMA foreign_keys = ON")
        
        // Insert a test chat
        let chatId = UUID().uuidString
        try testConnection.run(DatabaseSchema.Tables.chats.insert(
            DatabaseSchema.Tables.chatId <- chatId,
            DatabaseSchema.Tables.chatTitle <- "Test Chat",
            DatabaseSchema.Tables.chatCreatedAt <- Date(),
            DatabaseSchema.Tables.chatUpdatedAt <- Date(),
            DatabaseSchema.Tables.chatLLMProvider <- "openai",
            DatabaseSchema.Tables.chatModelName <- "gpt-4",
            DatabaseSchema.Tables.chatIsArchived <- false,
            DatabaseSchema.Tables.chatMessageCount <- 0
        ))
        
        // Insert a message with valid chat_id
        let messageId = UUID().uuidString
        try testConnection.run(DatabaseSchema.Tables.messages.insert(
            DatabaseSchema.Tables.messageId <- messageId,
            DatabaseSchema.Tables.messageChatId <- chatId,
            DatabaseSchema.Tables.messageContent <- "Test message",
            DatabaseSchema.Tables.messageIsUser <- true,
            DatabaseSchema.Tables.messageTimestamp <- Date(),
            DatabaseSchema.Tables.messageStatus <- "sent"
        ))
        
        // Verify message was inserted
        let messageCount = try testConnection.scalar(
            "SELECT COUNT(*) FROM messages WHERE id = ?", messageId
        ) as! Int64
        XCTAssertEqual(messageCount, 1, "Message should be inserted with valid chat_id")
        
        // Try to insert a message with invalid chat_id (should fail)
        let invalidChatId = UUID().uuidString
        XCTAssertThrowsError(try testConnection.run(DatabaseSchema.Tables.messages.insert(
            DatabaseSchema.Tables.messageId <- UUID().uuidString,
            DatabaseSchema.Tables.messageChatId <- invalidChatId,
            DatabaseSchema.Tables.messageContent <- "Test message",
            DatabaseSchema.Tables.messageIsUser <- true,
            DatabaseSchema.Tables.messageTimestamp <- Date(),
            DatabaseSchema.Tables.messageStatus <- "sent"
        )), "Should throw error for invalid chat_id")
    }
    
    // MARK: - Query Builder Tests
    
    func testSearchQueryBuilder() throws {
        // Test chat search query building
        let chatSearchQuery = SearchQueryBuilder.buildChatSearchQuery(
            searchTerm: "test",
            provider: .openai,
            isArchived: false
        )
        
        XCTAssertTrue(chatSearchQuery.contains("LIKE '%test%'"), "Should include LIKE search")
        XCTAssertTrue(chatSearchQuery.contains("llm_provider = 'openai'"), "Should filter by provider")
        XCTAssertTrue(chatSearchQuery.contains("is_archived = 0"), "Should filter by archived status")
        XCTAssertTrue(chatSearchQuery.contains("ORDER BY chats.updated_at DESC"), "Should order by updated_at")
        
        // Test message search query building
        let messageSearchQuery = SearchQueryBuilder.buildMessageSearchQuery(
            searchTerm: "hello",
            chatId: UUID().uuidString,
            isUser: true
        )
        
        XCTAssertTrue(messageSearchQuery.contains("LIKE '%hello%'"), "Should include LIKE search")
        XCTAssertTrue(messageSearchQuery.contains("chat_id ="), "Should filter by chat_id")
        XCTAssertTrue(messageSearchQuery.contains("is_user = 1"), "Should filter by user status")
        XCTAssertTrue(messageSearchQuery.contains("ORDER BY messages.timestamp DESC"), "Should order by timestamp")
    }
    
    // MARK: - Statistics Tests
    
    func testQueryOptimizer() throws {
        // Create tables
        try DatabaseSchema.createTables(db: testConnection)
        
        // Insert test data
        let chatId = UUID().uuidString
        try testConnection.run(DatabaseSchema.Tables.chats.insert(
            DatabaseSchema.Tables.chatId <- chatId,
            DatabaseSchema.Tables.chatTitle <- "Test Chat",
            DatabaseSchema.Tables.chatCreatedAt <- Date(),
            DatabaseSchema.Tables.chatUpdatedAt <- Date(),
            DatabaseSchema.Tables.chatLLMProvider <- "openai",
            DatabaseSchema.Tables.chatModelName <- "gpt-4",
            DatabaseSchema.Tables.chatIsArchived <- false,
            DatabaseSchema.Tables.chatMessageCount <- 0
        ))
        
        // Test database statistics
        let stats = try DatabaseSchema.QueryOptimizer.getDatabaseStats(db: testConnection)
        
        XCTAssertEqual(stats.chatCount, 1, "Should have 1 chat")
        XCTAssertEqual(stats.messageCount, 0, "Should have 0 messages")
        XCTAssertGreaterThan(stats.totalSizeBytes, 0, "Database should have some size")
        XCTAssertGreaterThan(stats.indexCount, 0, "Should have indexes")
    }
    
    func testAnalyzeQuery() throws {
        // Create tables
        try DatabaseSchema.createTables(db: testConnection)
        
        // Analyze a simple query
        let query = "SELECT * FROM chats WHERE is_archived = 0"
        let analysis = try DatabaseSchema.QueryOptimizer.analyzeQuery(query, db: testConnection)
        
        XCTAssertNotNil(analysis["plan"], "Should have query plan")
    }
    
    // MARK: - Index Performance Tests
    
    func testIndexPerformance() throws {
        // Create tables
        try DatabaseSchema.createTables(db: testConnection)
        
        // Insert test data
        let chatCount = 1000
        for i in 0..<chatCount {
            let chatId = UUID().uuidString
            try testConnection.run(DatabaseSchema.Tables.chats.insert(
                DatabaseSchema.Tables.chatId <- chatId,
                DatabaseSchema.Tables.chatTitle <- "Test Chat \(i)",
                DatabaseSchema.Tables.chatCreatedAt <- Date(),
                DatabaseSchema.Tables.chatUpdatedAt <- Date(),
                DatabaseSchema.Tables.chatLLMProvider <- "openai",
                DatabaseSchema.Tables.chatModelName <- "gpt-4",
                DatabaseSchema.Tables.chatIsArchived <- i % 2 == 0,
                DatabaseSchema.Tables.chatMessageCount <- 0
            ))
        }
        
        // Measure performance of indexed query
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Query using index
        let results = try testConnection.prepare(
            "SELECT * FROM chats WHERE is_archived = 0 ORDER BY updated_at DESC LIMIT 10"
        )
        
        var resultCount = 0
        for _ in results {
            resultCount += 1
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let queryTime = endTime - startTime
        
        XCTAssertEqual(resultCount, 10, "Should return 10 results")
        XCTAssertLessThan(queryTime, 0.1, "Query should complete in under 100ms")
    }
    
    // MARK: - Search Tests
    
    func testLikeSearch() throws {
        // Create tables
        try DatabaseSchema.createTables(db: testConnection)
        
        // Insert test data
        let chatId = UUID().uuidString
        try testConnection.run(DatabaseSchema.Tables.chats.insert(
            DatabaseSchema.Tables.chatId <- chatId,
            DatabaseSchema.Tables.chatTitle <- "Machine Learning Discussion",
            DatabaseSchema.Tables.chatCreatedAt <- Date(),
            DatabaseSchema.Tables.chatUpdatedAt <- Date(),
            DatabaseSchema.Tables.chatLLMProvider <- "openai",
            DatabaseSchema.Tables.chatModelName <- "gpt-4",
            DatabaseSchema.Tables.chatIsArchived <- false,
            DatabaseSchema.Tables.chatMessageCount <- 0,
            DatabaseSchema.Tables.chatLastMessagePreview <- "Let's talk about neural networks"
        ))
        
        // Test LIKE search
        let searchResults = try testConnection.prepare(
            "SELECT * FROM chats WHERE title LIKE '%Machine%' OR last_message_preview LIKE '%Machine%'"
        )
        
        var resultCount = 0
        for _ in searchResults {
            resultCount += 1
        }
        
        XCTAssertEqual(resultCount, 1, "Should find 1 result for 'Machine' search")
    }
    
    // MARK: - Helper Methods
    
    private func getTableColumns(table: String) throws -> [String] {
        var columns: [String] = []
        
        for row in try testConnection.prepare("PRAGMA table_info(\(table))") {
            if let columnName = row[1] as? String {
                columns.append(columnName)
            }
        }
        
        return columns
    }
    
    // MARK: - Schema Version Tests
    
    func testSchemaVersion() {
        XCTAssertEqual(DatabaseSchema.currentVersion, 2, "Current schema version should be 2")
    }
    
    func testTableDefinitions() {
        // Test that table definitions are properly structured
        XCTAssertNotNil(DatabaseSchema.Tables.chats, "Chats table should be defined")
        XCTAssertNotNil(DatabaseSchema.Tables.messages, "Messages table should be defined")
        XCTAssertNotNil(DatabaseSchema.Tables.settings, "Settings table should be defined")
        XCTAssertNotNil(DatabaseSchema.Tables.chatStats, "Chat stats table should be defined")
    }
}