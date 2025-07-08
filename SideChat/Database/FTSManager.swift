import Foundation
import SQLite

// MARK: - FTS Manager

/// FTSManager handles Full Text Search operations for the SideChat database
/// Provides a safe abstraction layer for FTS operations with error handling and fallback search
class FTSManager: ObservableObject {
    private weak var db: Connection?
    
    // MARK: - FTS Table Names
    
    private let chatsFTSTable = "chats_fts"
    private let messagesFTSTable = "messages_fts"
    
    // MARK: - Initialization
    
    init(database: Connection?) {
        self.db = database
    }
    
    // MARK: - FTS Setup
    
    /// Creates FTS tables if they don't exist
    func setupFTSTables() async throws {
        guard let db = db else {
            throw FTSError.databaseNotAvailable
        }
        
        do {
            // Create FTS tables
            try await createChatsFTSTable(db: db)
            try await createMessagesFTSTable(db: db)
            
            // Check if tables need initial population
            if try await needsInitialPopulation(db: db) {
                try await populateInitialData(db: db)
            }
            
            print("FTS tables setup completed successfully")
        } catch {
            print("Failed to setup FTS tables: \(error)")
            throw FTSError.setupFailed(reason: error.localizedDescription)
        }
    }
    
    private func createChatsFTSTable(db: Connection) async throws {
        try db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS \(chatsFTSTable) USING fts5(
                title,
                last_message_preview,
                content='chats',
                content_rowid='rowid',
                tokenize='unicode61'
            )
        """)
    }
    
    private func createMessagesFTSTable(db: Connection) async throws {
        try db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS \(messagesFTSTable) USING fts5(
                content,
                content='messages',
                content_rowid='rowid',
                tokenize='unicode61'
            )
        """)
    }
    
    // MARK: - FTS Population
    
    private func needsInitialPopulation(db: Connection) async throws -> Bool {
        // Check if FTS tables have any data
        let chatsFTSCount = try db.scalar("SELECT COUNT(*) FROM \(chatsFTSTable)") as! Int64
        let messagesFTSCount = try db.scalar("SELECT COUNT(*) FROM \(messagesFTSTable)") as! Int64
        
        // Check if main tables have data
        let chatsCount = try db.scalar("SELECT COUNT(*) FROM chats") as! Int64
        let messagesCount = try db.scalar("SELECT COUNT(*) FROM messages") as! Int64
        
        // Need population if main tables have data but FTS tables don't
        return (chatsCount > 0 && chatsFTSCount == 0) || (messagesCount > 0 && messagesFTSCount == 0)
    }
    
    private func populateInitialData(db: Connection) async throws {
        // Populate chats FTS
        try db.execute("""
            INSERT INTO \(chatsFTSTable)(rowid, title, last_message_preview)
            SELECT rowid, title, last_message_preview FROM chats
        """)
        
        // Populate messages FTS
        try db.execute("""
            INSERT INTO \(messagesFTSTable)(rowid, content)
            SELECT rowid, content FROM messages
        """)
        
        print("FTS tables populated with initial data")
    }
    
    // MARK: - Search Operations
    
    /// Search chats using FTS with fallback to LIKE queries
    func searchChats(query: String) async throws -> [String] {
        guard let db = db else {
            throw FTSError.databaseNotAvailable
        }
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        do {
            // Try FTS search first
            return try await searchChatsWithFTS(query: query, db: db)
        } catch {
            print("FTS search failed, falling back to LIKE query: \(error)")
            // Fallback to LIKE query
            return try await searchChatsWithLIKE(query: query, db: db)
        }
    }
    
    private func searchChatsWithFTS(query: String, db: Connection) async throws -> [String] {
        let sanitizedQuery = sanitizeFTSQuery(query)
        let ftsQuery = """
            SELECT c.id
            FROM chats c
            JOIN \(chatsFTSTable) fts ON c.rowid = fts.rowid
            WHERE fts MATCH ?
            ORDER BY rank
        """
        
        var chatIds: [String] = []
        for row in try db.prepare(ftsQuery, sanitizedQuery) {
            if let id = row[0] as? String {
                chatIds.append(id)
            }
        }
        
        return chatIds
    }
    
    private func searchChatsWithLIKE(query: String, db: Connection) async throws -> [String] {
        let likeQuery = "%\(query)%"
        let sqlQuery = """
            SELECT id
            FROM chats
            WHERE title LIKE ? OR last_message_preview LIKE ?
            ORDER BY updated_at DESC
        """
        
        var chatIds: [String] = []
        for row in try db.prepare(sqlQuery, likeQuery, likeQuery) {
            if let id = row[0] as? String {
                chatIds.append(id)
            }
        }
        
        return chatIds
    }
    
    /// Search messages using FTS with fallback to LIKE queries
    func searchMessages(query: String, chatId: String? = nil) async throws -> [String] {
        guard let db = db else {
            throw FTSError.databaseNotAvailable
        }
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        do {
            // Try FTS search first
            return try await searchMessagesWithFTS(query: query, chatId: chatId, db: db)
        } catch {
            print("FTS search failed, falling back to LIKE query: \(error)")
            // Fallback to LIKE query
            return try await searchMessagesWithLIKE(query: query, chatId: chatId, db: db)
        }
    }
    
    private func searchMessagesWithFTS(query: String, chatId: String?, db: Connection) async throws -> [String] {
        let sanitizedQuery = sanitizeFTSQuery(query)
        var ftsQuery = """
            SELECT m.id
            FROM messages m
            JOIN \(messagesFTSTable) fts ON m.rowid = fts.rowid
            WHERE fts MATCH ?
        """
        
        if let chatId = chatId {
            ftsQuery += " AND m.chat_id = ?"
        }
        
        ftsQuery += " ORDER BY rank"
        
        var messageIds: [String] = []
        let statement = chatId != nil 
            ? try db.prepare(ftsQuery, sanitizedQuery, chatId!)
            : try db.prepare(ftsQuery, sanitizedQuery)
        
        for row in statement {
            if let id = row[0] as? String {
                messageIds.append(id)
            }
        }
        
        return messageIds
    }
    
    private func searchMessagesWithLIKE(query: String, chatId: String?, db: Connection) async throws -> [String] {
        let likeQuery = "%\(query)%"
        var sqlQuery = """
            SELECT id
            FROM messages
            WHERE content LIKE ?
        """
        
        if let chatId = chatId {
            sqlQuery += " AND chat_id = ?"
        }
        
        sqlQuery += " ORDER BY timestamp DESC"
        
        var messageIds: [String] = []
        let statement = chatId != nil
            ? try db.prepare(sqlQuery, likeQuery, chatId!)
            : try db.prepare(sqlQuery, likeQuery)
        
        for row in statement {
            if let id = row[0] as? String {
                messageIds.append(id)
            }
        }
        
        return messageIds
    }
    
    // MARK: - FTS Synchronization
    
    /// Synchronize chat data with FTS table
    func syncChat(chatId: String, title: String, lastMessagePreview: String?) async throws {
        guard let db = db else {
            throw FTSError.databaseNotAvailable
        }
        
        do {
            // Get the rowid for the chat
            let rowidQuery = "SELECT rowid FROM chats WHERE id = ?"
            guard let rowid = try db.scalar(rowidQuery, chatId) as? Int64 else {
                throw FTSError.recordNotFound(id: chatId)
            }
            
            // Check if FTS record exists
            let existsQuery = "SELECT COUNT(*) FROM \(chatsFTSTable) WHERE rowid = ?"
            let exists = try db.scalar(existsQuery, rowid) as! Int64 > 0
            
            if exists {
                // Update existing FTS record
                try db.run("""
                    UPDATE \(chatsFTSTable)
                    SET title = ?, last_message_preview = ?
                    WHERE rowid = ?
                """, title, lastMessagePreview ?? "", rowid)
            } else {
                // Insert new FTS record
                try db.run("""
                    INSERT INTO \(chatsFTSTable)(rowid, title, last_message_preview)
                    VALUES (?, ?, ?)
                """, rowid, title, lastMessagePreview ?? "")
            }
        } catch {
            print("Failed to sync chat to FTS: \(error)")
            // Don't throw - FTS sync failure shouldn't break main functionality
        }
    }
    
    /// Synchronize message data with FTS table
    func syncMessage(messageId: String, content: String) async throws {
        guard let db = db else {
            throw FTSError.databaseNotAvailable
        }
        
        do {
            // Get the rowid for the message
            let rowidQuery = "SELECT rowid FROM messages WHERE id = ?"
            guard let rowid = try db.scalar(rowidQuery, messageId) as? Int64 else {
                throw FTSError.recordNotFound(id: messageId)
            }
            
            // Check if FTS record exists
            let existsQuery = "SELECT COUNT(*) FROM \(messagesFTSTable) WHERE rowid = ?"
            let exists = try db.scalar(existsQuery, rowid) as! Int64 > 0
            
            if exists {
                // Update existing FTS record
                try db.run("""
                    UPDATE \(messagesFTSTable)
                    SET content = ?
                    WHERE rowid = ?
                """, content, rowid)
            } else {
                // Insert new FTS record
                try db.run("""
                    INSERT INTO \(messagesFTSTable)(rowid, content)
                    VALUES (?, ?)
                """, rowid, content)
            }
        } catch {
            print("Failed to sync message to FTS: \(error)")
            // Don't throw - FTS sync failure shouldn't break main functionality
        }
    }
    
    /// Remove chat from FTS index
    func removeChat(chatId: String) async throws {
        guard let db = db else {
            throw FTSError.databaseNotAvailable
        }
        
        do {
            // Get the rowid for the chat
            let rowidQuery = "SELECT rowid FROM chats WHERE id = ?"
            if let rowid = try db.scalar(rowidQuery, chatId) as? Int64 {
                try db.run("DELETE FROM \(chatsFTSTable) WHERE rowid = ?", rowid)
            }
        } catch {
            print("Failed to remove chat from FTS: \(error)")
            // Don't throw - FTS removal failure shouldn't break main functionality
        }
    }
    
    /// Remove message from FTS index
    func removeMessage(messageId: String) async throws {
        guard let db = db else {
            throw FTSError.databaseNotAvailable
        }
        
        do {
            // Get the rowid for the message
            let rowidQuery = "SELECT rowid FROM messages WHERE id = ?"
            if let rowid = try db.scalar(rowidQuery, messageId) as? Int64 {
                try db.run("DELETE FROM \(messagesFTSTable) WHERE rowid = ?", rowid)
            }
        } catch {
            print("Failed to remove message from FTS: \(error)")
            // Don't throw - FTS removal failure shouldn't break main functionality
        }
    }
    
    // MARK: - FTS Health Check
    
    /// Check the health of FTS tables
    func checkFTSHealth() async throws -> FTSHealthStatus {
        guard let db = db else {
            throw FTSError.databaseNotAvailable
        }
        
        var status = FTSHealthStatus()
        
        // Check if tables exist
        status.tablesExist = try checkFTSTablesExist(db: db)
        
        if status.tablesExist {
            // Check synchronization status
            let (chatsSynced, messagesSynced) = try await checkSynchronization(db: db)
            status.chatsSynchronized = chatsSynced
            status.messagesSynchronized = messagesSynced
            
            // Check for corruption
            status.isCorrupted = try await checkForCorruption(db: db)
        }
        
        return status
    }
    
    private func checkFTSTablesExist(db: Connection) throws -> Bool {
        let query = """
            SELECT COUNT(*) FROM sqlite_master 
            WHERE type='table' AND (name=? OR name=?)
        """
        let count = try db.scalar(query, chatsFTSTable, messagesFTSTable) as! Int64
        return count == 2
    }
    
    private func checkSynchronization(db: Connection) async throws -> (Bool, Bool) {
        // Check chats synchronization
        let chatsSyncQuery = """
            SELECT COUNT(*) FROM chats c
            LEFT JOIN \(chatsFTSTable) fts ON c.rowid = fts.rowid
            WHERE fts.rowid IS NULL
        """
        let unsyncedChats = try db.scalar(chatsSyncQuery) as! Int64
        
        // Check messages synchronization
        let messagesSyncQuery = """
            SELECT COUNT(*) FROM messages m
            LEFT JOIN \(messagesFTSTable) fts ON m.rowid = fts.rowid
            WHERE fts.rowid IS NULL
        """
        let unsyncedMessages = try db.scalar(messagesSyncQuery) as! Int64
        
        return (unsyncedChats == 0, unsyncedMessages == 0)
    }
    
    private func checkForCorruption(db: Connection) async throws -> Bool {
        do {
            // Try a simple FTS query on each table
            _ = try db.scalar("SELECT COUNT(*) FROM \(chatsFTSTable) WHERE \(chatsFTSTable) MATCH 'test'")
            _ = try db.scalar("SELECT COUNT(*) FROM \(messagesFTSTable) WHERE \(messagesFTSTable) MATCH 'test'")
            return false
        } catch {
            // If queries fail, tables might be corrupted
            return true
        }
    }
    
    /// Rebuild FTS tables from scratch
    func rebuildFTSTables() async throws {
        guard let db = db else {
            throw FTSError.databaseNotAvailable
        }
        
        print("Rebuilding FTS tables...")
        
        // Drop existing FTS tables
        try db.execute("DROP TABLE IF EXISTS \(chatsFTSTable)")
        try db.execute("DROP TABLE IF EXISTS \(messagesFTSTable)")
        
        // Recreate and populate
        try await setupFTSTables()
        
        print("FTS tables rebuilt successfully")
    }
    
    // MARK: - Utility Functions
    
    private func sanitizeFTSQuery(_ query: String) -> String {
        // Remove special FTS characters and add prefix matching
        let cleaned = query
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "OR", with: "")
            .replacingOccurrences(of: "AND", with: "")
            .replacingOccurrences(of: "NOT", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add prefix matching for better search experience
        return "\(cleaned)*"
    }
}

// MARK: - FTS Error Types

enum FTSError: LocalizedError {
    case databaseNotAvailable
    case setupFailed(reason: String)
    case recordNotFound(id: String)
    case searchFailed(reason: String)
    case syncFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .databaseNotAvailable:
            return "Database connection not available"
        case .setupFailed(let reason):
            return "Failed to setup FTS: \(reason)"
        case .recordNotFound(let id):
            return "Record not found: \(id)"
        case .searchFailed(let reason):
            return "Search failed: \(reason)"
        case .syncFailed(let reason):
            return "Synchronization failed: \(reason)"
        }
    }
}

// MARK: - FTS Health Status

struct FTSHealthStatus {
    var tablesExist: Bool = false
    var chatsSynchronized: Bool = false
    var messagesSynchronized: Bool = false
    var isCorrupted: Bool = false
    
    var isHealthy: Bool {
        return tablesExist && chatsSynchronized && messagesSynchronized && !isCorrupted
    }
    
    var description: String {
        if isHealthy {
            return "FTS is healthy"
        }
        
        var issues: [String] = []
        if !tablesExist {
            issues.append("FTS tables don't exist")
        }
        if !chatsSynchronized {
            issues.append("Chats not fully synchronized")
        }
        if !messagesSynchronized {
            issues.append("Messages not fully synchronized")
        }
        if isCorrupted {
            issues.append("FTS tables appear corrupted")
        }
        
        return "FTS issues: \(issues.joined(separator: ", "))"
    }
}