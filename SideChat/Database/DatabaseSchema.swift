import Foundation
import SQLite

// MARK: - Database Schema

/// DatabaseSchema defines the complete database structure with optimized indexing
/// Includes full-text search capabilities and performance indexes for the SideChat app

struct DatabaseSchema {
    
    // MARK: - Schema Version
    static let currentVersion = 2
    
    // MARK: - Table Definitions
    
    struct Tables {
        // Chats table
        static let chats = Table("chats")
        static let chatId = Expression<String>("id")
        static let chatTitle = Expression<String>("title")
        static let chatCreatedAt = Expression<Date>("created_at")
        static let chatUpdatedAt = Expression<Date>("updated_at")
        static let chatLLMProvider = Expression<String>("llm_provider")
        static let chatModelName = Expression<String>("model_name")
        static let chatIsArchived = Expression<Bool>("is_archived")
        static let chatMessageCount = Expression<Int>("message_count")
        static let chatLastMessagePreview = Expression<String?>("last_message_preview")
        
        // Messages table
        static let messages = Table("messages")
        static let messageId = Expression<String>("id")
        static let messageChatId = Expression<String>("chat_id")
        static let messageContent = Expression<String>("content")
        static let messageIsUser = Expression<Bool>("is_user")
        static let messageTimestamp = Expression<Date>("timestamp")
        static let messageImageData = Expression<Data?>("image_data")
        static let messageStatus = Expression<String>("status")
        static let messageEditedAt = Expression<Date?>("edited_at")
        static let messageModel = Expression<String?>("model")
        static let messageProvider = Expression<String?>("provider")
        static let messageResponseTime = Expression<Double?>("response_time")
        static let messagePromptTokens = Expression<Int?>("prompt_tokens")
        static let messageResponseTokens = Expression<Int?>("response_tokens")
        static let messageTotalTokens = Expression<Int?>("total_tokens")
        
        // Full-text search tables (created via raw SQL)
        
        // Settings table for app configuration
        static let settings = Table("settings")
        static let settingKey = Expression<String>("key")
        static let settingValue = Expression<String>("value")
        static let settingType = Expression<String>("type")
        static let settingUpdatedAt = Expression<Date>("updated_at")
        
        // Chat statistics table for analytics
        static let chatStats = Table("chat_stats")
        static let statId = Expression<String>("id")
        static let statChatId = Expression<String>("chat_id")
        static let statDate = Expression<Date>("date")
        static let statMessageCount = Expression<Int>("message_count")
        static let statWordCount = Expression<Int>("word_count")
        static let statTokenCount = Expression<Int>("token_count")
        static let statResponseTime = Expression<Double>("avg_response_time")
    }
    
    // MARK: - Index Definitions
    
    struct Indexes {
        // Core performance indexes
        static let chatUpdatedAtIndex = "idx_chats_updated_at"
        static let chatIsArchivedIndex = "idx_chats_is_archived"
        static let chatProviderIndex = "idx_chats_provider"
        static let chatTitleIndex = "idx_chats_title"
        
        static let messageChatIdIndex = "idx_messages_chat_id"
        static let messageTimestampIndex = "idx_messages_timestamp"
        static let messageIsUserIndex = "idx_messages_is_user"
        static let messageStatusIndex = "idx_messages_status"
        static let messageProviderIndex = "idx_messages_provider"
        
        // Composite indexes for common queries
        static let chatProviderArchivedIndex = "idx_chats_provider_archived"
        static let messagesChatTimestampIndex = "idx_messages_chat_timestamp"
        static let messagesUserTimestampIndex = "idx_messages_user_timestamp"
        
        // Statistics indexes
        static let chatStatsDateIndex = "idx_chat_stats_date"
        static let chatStatsChatIndex = "idx_chat_stats_chat"
        
        // Settings index
        static let settingsKeyIndex = "idx_settings_key"
    }
    
    // MARK: - Schema Creation
    
    static func createTables(db: Connection) throws {
        // Create main tables
        try createChatsTable(db: db)
        try createMessagesTable(db: db)
        try createSettingsTable(db: db)
        try createChatStatsTable(db: db)
        
        // Create indexes
        try createIndexes(db: db)
        
        // FTS is now handled by FTSManager - no longer created here
        // Triggers removed to prevent database corruption issues
    }
    
    private static func createChatsTable(db: Connection) throws {
        try db.run(Tables.chats.create(ifNotExists: true) { t in
            t.column(Tables.chatId, primaryKey: true)
            t.column(Tables.chatTitle)
            t.column(Tables.chatCreatedAt)
            t.column(Tables.chatUpdatedAt)
            t.column(Tables.chatLLMProvider)
            t.column(Tables.chatModelName)
            t.column(Tables.chatIsArchived, defaultValue: false)
            t.column(Tables.chatMessageCount, defaultValue: 0)
            t.column(Tables.chatLastMessagePreview)
        })
    }
    
    private static func createMessagesTable(db: Connection) throws {
        try db.run(Tables.messages.create(ifNotExists: true) { t in
            t.column(Tables.messageId, primaryKey: true)
            t.column(Tables.messageChatId)
            t.column(Tables.messageContent)
            t.column(Tables.messageIsUser)
            t.column(Tables.messageTimestamp)
            t.column(Tables.messageImageData)
            t.column(Tables.messageStatus)
            t.column(Tables.messageEditedAt)
            t.column(Tables.messageModel)
            t.column(Tables.messageProvider)
            t.column(Tables.messageResponseTime)
            t.column(Tables.messagePromptTokens)
            t.column(Tables.messageResponseTokens)
            t.column(Tables.messageTotalTokens)
            t.foreignKey(Tables.messageChatId, references: Tables.chats, Tables.chatId, delete: .cascade)
        })
    }
    
    private static func createSettingsTable(db: Connection) throws {
        try db.run(Tables.settings.create(ifNotExists: true) { t in
            t.column(Tables.settingKey, primaryKey: true)
            t.column(Tables.settingValue)
            t.column(Tables.settingType)
            t.column(Tables.settingUpdatedAt)
        })
    }
    
    private static func createChatStatsTable(db: Connection) throws {
        try db.run(Tables.chatStats.create(ifNotExists: true) { t in
            t.column(Tables.statId, primaryKey: true)
            t.column(Tables.statChatId)
            t.column(Tables.statDate)
            t.column(Tables.statMessageCount, defaultValue: 0)
            t.column(Tables.statWordCount, defaultValue: 0)
            t.column(Tables.statTokenCount, defaultValue: 0)
            t.column(Tables.statResponseTime, defaultValue: 0.0)
            t.foreignKey(Tables.statChatId, references: Tables.chats, Tables.chatId, delete: .cascade)
        })
    }
    
    private static func createFullTextSearchTables(db: Connection) throws {
        // Create FTS table for chats using raw SQL for better control
        try db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS chats_fts USING fts5(
                title,
                last_message_preview,
                content='chats',
                content_rowid='rowid'
            )
        """)
        
        // Create FTS table for messages using raw SQL
        try db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
                content,
                content='messages',
                content_rowid='rowid'
            )
        """)
    }
    
    private static func createIndexes(db: Connection) throws {
        // Chat indexes with explicit names
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.chatUpdatedAtIndex) ON chats(updated_at)")
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.chatIsArchivedIndex) ON chats(is_archived)")
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.chatProviderIndex) ON chats(llm_provider)")
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.chatTitleIndex) ON chats(title)")
        
        // Message indexes with explicit names
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.messageChatIdIndex) ON messages(chat_id)")
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.messageTimestampIndex) ON messages(timestamp)")
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.messageIsUserIndex) ON messages(is_user)")
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.messageStatusIndex) ON messages(status)")
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.messageProviderIndex) ON messages(provider)")
        
        // Statistics indexes with explicit names
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.chatStatsDateIndex) ON chat_stats(date)")
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.chatStatsChatIndex) ON chat_stats(chat_id)")
        
        // Settings index with explicit name
        try db.execute("CREATE INDEX IF NOT EXISTS \(Indexes.settingsKeyIndex) ON settings(key)")
        
        // Create composite indexes using raw SQL for better control
        try createCompositeIndexes(db: db)
    }
    
    private static func createCompositeIndexes(db: Connection) throws {
        // Composite indexes for common query patterns
        try db.execute("""
            CREATE INDEX IF NOT EXISTS idx_chats_provider_archived 
            ON chats(llm_provider, is_archived)
        """)
        
        try db.execute("""
            CREATE INDEX IF NOT EXISTS idx_messages_chat_timestamp 
            ON messages(chat_id, timestamp)
        """)
        
        try db.execute("""
            CREATE INDEX IF NOT EXISTS idx_messages_user_timestamp 
            ON messages(is_user, timestamp)
        """)
    }
    
    private static func createTriggers(db: Connection) throws {
        // Trigger to update chat stats when messages are inserted
        try db.execute("""
            CREATE TRIGGER IF NOT EXISTS update_chat_stats_insert
            AFTER INSERT ON messages
            BEGIN
                UPDATE chats 
                SET message_count = message_count + 1,
                    updated_at = datetime('now'),
                    last_message_preview = CASE 
                        WHEN length(NEW.content) > 100 
                        THEN substr(NEW.content, 1, 100) || '...'
                        ELSE NEW.content
                    END
                WHERE id = NEW.chat_id;
                
                -- Insert FTS record
                INSERT INTO messages_fts(rowid, content) 
                VALUES (NEW.rowid, NEW.content);
            END;
        """)
        
        // Trigger to update chat stats when messages are deleted
        try db.execute("""
            CREATE TRIGGER IF NOT EXISTS update_chat_stats_delete
            AFTER DELETE ON messages
            BEGIN
                UPDATE chats 
                SET message_count = message_count - 1,
                    updated_at = datetime('now')
                WHERE id = OLD.chat_id;
                
                -- Update last message preview
                UPDATE chats 
                SET last_message_preview = (
                    SELECT CASE 
                        WHEN length(content) > 100 
                        THEN substr(content, 1, 100) || '...'
                        ELSE content
                    END
                    FROM messages 
                    WHERE chat_id = OLD.chat_id 
                    ORDER BY timestamp DESC 
                    LIMIT 1
                )
                WHERE id = OLD.chat_id;
                
                -- Delete FTS record
                DELETE FROM messages_fts WHERE rowid = OLD.rowid;
            END;
        """)
        
        // Trigger to maintain FTS index for chats
        try db.execute("""
            CREATE TRIGGER IF NOT EXISTS update_chats_fts_insert
            AFTER INSERT ON chats
            BEGIN
                INSERT INTO chats_fts(rowid, title, last_message_preview) 
                VALUES (NEW.rowid, NEW.title, NEW.last_message_preview);
            END;
        """)
        
        try db.execute("""
            CREATE TRIGGER IF NOT EXISTS update_chats_fts_update
            AFTER UPDATE ON chats
            BEGIN
                UPDATE chats_fts 
                SET title = NEW.title, 
                    last_message_preview = NEW.last_message_preview
                WHERE rowid = NEW.rowid;
            END;
        """)
        
        try db.execute("""
            CREATE TRIGGER IF NOT EXISTS update_chats_fts_delete
            AFTER DELETE ON chats
            BEGIN
                DELETE FROM chats_fts WHERE rowid = OLD.rowid;
            END;
        """)
    }
    
    // MARK: - Schema Migration
    
    static func migrateSchema(db: Connection, from oldVersion: Int, to newVersion: Int) throws {
        // Future migration logic would go here
        // For now, we're at version 1, so no migrations needed
        print("Schema migration from version \(oldVersion) to \(newVersion)")
    }
    
    // MARK: - Query Optimization Helpers
    
    struct QueryOptimizer {
        // Analyze query performance
        static func analyzeQuery(_ query: String, db: Connection) throws -> [String: Any] {
            let analyzeQuery = "EXPLAIN QUERY PLAN \(query)"
            var results: [String: Any] = [:]
            
            for row in try db.prepare(analyzeQuery) {
                // Extract query plan information
                if let detail = row[3] as? String {
                    results["plan"] = detail
                }
            }
            
            return results
        }
        
        // Get database statistics
        static func getDatabaseStats(db: Connection) throws -> DatabaseStats {
            let chatCount = try db.scalar(Tables.chats.count)
            let messageCount = try db.scalar(Tables.messages.count)
            let totalSize = try getDatabaseSize(db: db)
            
            return DatabaseStats(
                chatCount: chatCount,
                messageCount: messageCount,
                totalSizeBytes: totalSize,
                indexCount: try getIndexCount(db: db)
            )
        }
        
        private static func getDatabaseSize(db: Connection) throws -> Int64 {
            let pageCount = try db.scalar("PRAGMA page_count") as! Int64
            let pageSize = try db.scalar("PRAGMA page_size") as! Int64
            return pageCount * pageSize
        }
        
        private static func getIndexCount(db: Connection) throws -> Int {
            let indexQuery = "SELECT COUNT(*) FROM sqlite_master WHERE type='index'"
            let count = try db.scalar(indexQuery) as! Int64
            return Int(count)
        }
    }
}

// MARK: - Database Statistics

struct DatabaseStats {
    let chatCount: Int
    let messageCount: Int
    let totalSizeBytes: Int64
    let indexCount: Int
    
    var totalSizeMB: Double {
        return Double(totalSizeBytes) / (1024.0 * 1024.0)
    }
    
    var averageMessagesPerChat: Double {
        guard chatCount > 0 else { return 0.0 }
        return Double(messageCount) / Double(chatCount)
    }
}

// MARK: - Search Query Builder

struct SearchQueryBuilder {
    static func buildChatSearchQuery(
        searchTerm: String,
        provider: LLMProvider? = nil,
        isArchived: Bool? = nil,
        dateRange: (from: Date, to: Date)? = nil
    ) -> String {
        var conditions: [String] = []
        
        // Full-text search condition
        if !searchTerm.isEmpty {
            conditions.append("chats.id IN (SELECT rowid FROM chats_fts WHERE chats_fts MATCH '\(searchTerm)*')")
        }
        
        // Provider filter
        if let provider = provider {
            conditions.append("chats.llm_provider = '\(provider.rawValue)'")
        }
        
        // Archive filter
        if let isArchived = isArchived {
            conditions.append("chats.is_archived = \(isArchived ? 1 : 0)")
        }
        
        // Date range filter
        if let dateRange = dateRange {
            conditions.append("chats.created_at BETWEEN '\(dateRange.from.iso8601)' AND '\(dateRange.to.iso8601)'")
        }
        
        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        return "SELECT * FROM chats \(whereClause) ORDER BY chats.updated_at DESC"
    }
    
    static func buildMessageSearchQuery(
        searchTerm: String,
        chatId: String? = nil,
        isUser: Bool? = nil,
        dateRange: (from: Date, to: Date)? = nil
    ) -> String {
        var conditions: [String] = []
        
        // Full-text search condition
        if !searchTerm.isEmpty {
            conditions.append("messages.id IN (SELECT rowid FROM messages_fts WHERE messages_fts MATCH '\(searchTerm)*')")
        }
        
        // Chat filter
        if let chatId = chatId {
            conditions.append("messages.chat_id = '\(chatId)'")
        }
        
        // User filter
        if let isUser = isUser {
            conditions.append("messages.is_user = \(isUser ? 1 : 0)")
        }
        
        // Date range filter
        if let dateRange = dateRange {
            conditions.append("messages.timestamp BETWEEN '\(dateRange.from.iso8601)' AND '\(dateRange.to.iso8601)'")
        }
        
        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        return "SELECT * FROM messages \(whereClause) ORDER BY messages.timestamp DESC"
    }
}

// MARK: - Date Extension for ISO8601

extension Date {
    var iso8601: String {
        return ISO8601DateFormatter().string(from: self)
    }
}