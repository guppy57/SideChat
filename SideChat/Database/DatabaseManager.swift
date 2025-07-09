import Foundation
import SQLite
import Defaults

// MARK: - Database Manager

/// DatabaseManager provides type-safe SQLite database access using SQLite.swift
/// Handles all chat and message persistence with proper error handling and migration support

@MainActor
class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    private let databasePath: String
    private var isInitialized = false
    
    // MARK: - Test Support
    
    /// Creates a DatabaseManager instance for testing with a custom database path
    static func forTesting(databasePath: String) -> DatabaseManager {
        return DatabaseManager(customPath: databasePath)
    }
    
    // MARK: - Table Definitions (using DatabaseSchema)
    
    // Use schema definitions for consistency
    private let chats = DatabaseSchema.Tables.chats
    private let chatId = DatabaseSchema.Tables.chatId
    private let chatTitle = DatabaseSchema.Tables.chatTitle
    private let chatCreatedAt = DatabaseSchema.Tables.chatCreatedAt
    private let chatUpdatedAt = DatabaseSchema.Tables.chatUpdatedAt
    private let chatLLMProvider = DatabaseSchema.Tables.chatLLMProvider
    private let chatModelName = DatabaseSchema.Tables.chatModelName
    private let chatIsArchived = DatabaseSchema.Tables.chatIsArchived
    private let chatMessageCount = DatabaseSchema.Tables.chatMessageCount
    private let chatLastMessagePreview = DatabaseSchema.Tables.chatLastMessagePreview
    
    private let messages = DatabaseSchema.Tables.messages
    private let messageId = DatabaseSchema.Tables.messageId
    private let messageChatId = DatabaseSchema.Tables.messageChatId
    private let messageContent = DatabaseSchema.Tables.messageContent
    private let messageIsUser = DatabaseSchema.Tables.messageIsUser
    private let messageTimestamp = DatabaseSchema.Tables.messageTimestamp
    private let messageImageData = DatabaseSchema.Tables.messageImageData
    private let messageStatus = DatabaseSchema.Tables.messageStatus
    private let messageEditedAt = DatabaseSchema.Tables.messageEditedAt
    private let messageModel = DatabaseSchema.Tables.messageModel
    private let messageProvider = DatabaseSchema.Tables.messageProvider
    private let messageResponseTime = DatabaseSchema.Tables.messageResponseTime
    private let messagePromptTokens = DatabaseSchema.Tables.messagePromptTokens
    private let messageResponseTokens = DatabaseSchema.Tables.messageResponseTokens
    private let messageTotalTokens = DatabaseSchema.Tables.messageTotalTokens
    
    // MARK: - Initialization
    
    private init() {
        // Create database in app support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                 in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("SideChat")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, 
                                               withIntermediateDirectories: true)
        
        self.databasePath = appDirectory.appendingPathComponent("sidechat.db").path
        
        // Database initialization is now handled explicitly via initialize() method
        // This prevents unstructured Tasks during singleton creation
    }
    
    private init(customPath: String) {
        self.databasePath = customPath
        
        // Create parent directory if it doesn't exist
        let parentDirectory = URL(fileURLWithPath: customPath).deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDirectory,
                                               withIntermediateDirectories: true)
    }
    
    // MARK: - Public Initialization
    
    /// Initializes the database connection and performs migrations
    /// Must be called explicitly during app startup
    func initialize() async {
        guard !isInitialized else {
            print("Database already initialized, skipping duplicate initialization")
            return
        }
        isInitialized = true
        await initializeDatabase()
    }
    
    // MARK: - Database Setup
    
    private func initializeDatabase() async {
        do {
            // Check if database exists and try to validate it
            if FileManager.default.fileExists(atPath: databasePath) {
                let isValid = await validateDatabaseFile()
                if !isValid {
                    print("Database appears corrupted, removing and starting fresh...")
                    try? FileManager.default.removeItem(atPath: databasePath)
                    // Also remove WAL and SHM files if they exist
                    try? FileManager.default.removeItem(atPath: databasePath + "-wal")
                    try? FileManager.default.removeItem(atPath: databasePath + "-shm")
                }
            }
            
            // Check if encryption is enabled in settings
            let encryptionEnabled = Defaults[.enableDataEncryption]
            
            if encryptionEnabled {
                // Use encrypted connection
                db = try DatabaseSecurity.shared.createEncryptedConnection(to: databasePath)
            } else {
                // Use standard connection
                db = try Connection(databasePath)
            }
            
            // Enable foreign keys
            try db?.execute("PRAGMA foreign_keys = ON")
            
            // Enable write-ahead logging for better concurrency
            try db?.execute("PRAGMA journal_mode = WAL")
            
            // Set cache size for better performance
            try db?.execute("PRAGMA cache_size = -64000") // 64MB cache
            
            // Check database integrity
            if let integrityResult = try db?.scalar("PRAGMA integrity_check") as? String {
                if integrityResult != "ok" {
                    print("Database integrity check failed: \(integrityResult)")
                    // Database is corrupted, recover
                    await recoverFromDatabaseError()
                    return
                }
            }
            
            // Check if this is a fresh database and create tables if needed
            if let db = db {
                let tablesExist = try await checkTableExists(db: db, tableName: "chats")
                if !tablesExist {
                    print("Creating database tables for the first time...")
                    try DatabaseSchema.createTables(db: db)
                }
            }
            
            // Run migrations if needed
            if let db = db {
                try await DatabaseMigrator.shared.migrateIfNeeded(db: db)
            }
            
            // Validate schema
            if let db = db {
                let validation = try await DatabaseMigrator.shared.validateSchema(db: db)
                if !validation.isValid {
                    print("Schema validation warnings: \(validation.issues)")
                }
            }
            
            
            print("Database initialized at: \(databasePath)")
            
        } catch {
            print("Database initialization error: \(error)")
            if let migrationError = error as? DatabaseMigrationError {
                print("Migration error details: \(migrationError.localizedDescription)")
            }
            
            // If initialization fails, try to recover by creating a fresh database
            await recoverFromDatabaseError()
        }
    }
    
    private func createTables() async throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        // Use the new schema system for table creation
        try DatabaseSchema.createTables(db: db)
        
        print("Database tables created successfully")
    }
    
    // MARK: - Helper Methods
    
    private func ensureInitialized() throws {
        guard isInitialized else {
            throw DatabaseError.notInitialized
        }
        guard db != nil else {
            throw DatabaseError.connectionFailed
        }
    }
    
    // MARK: - Chat Operations
    
    func saveChat(_ chat: Chat) async throws {
        try ensureInitialized()
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        let insert = chats.insert(or: .replace,
            chatId <- chat.id.uuidString,
            chatTitle <- chat.title,
            chatCreatedAt <- chat.createdAt,
            chatUpdatedAt <- chat.updatedAt,
            chatLLMProvider <- chat.llmProvider.rawValue,
            chatModelName <- chat.modelName,
            chatIsArchived <- chat.isArchived,
            chatMessageCount <- chat.messageCount,
            chatLastMessagePreview <- chat.lastMessagePreview
        )
        
        try db.run(insert)
    }
    
    func loadChat(id: UUID) async throws -> Chat? {
        try ensureInitialized()
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        let query = chats.filter(chatId == id.uuidString).limit(1)
        
        for row in try db.prepare(query) {
            return Chat(
                id: UUID(uuidString: row[chatId])!,
                title: row[chatTitle],
                createdAt: row[chatCreatedAt],
                updatedAt: row[chatUpdatedAt],
                llmProvider: LLMProvider(rawValue: row[chatLLMProvider])!,
                modelName: row[chatModelName],
                isArchived: row[chatIsArchived],
                messageCount: row[chatMessageCount],
                lastMessagePreview: row[chatLastMessagePreview]
            )
        }
        
        return nil
    }
    
    func loadAllChats() async throws -> [Chat] {
        try ensureInitialized()
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        // Check if chats table exists
        let tableExists = try await checkTableExists(db: db, tableName: "chats")
        if !tableExists {
            print("Chats table does not exist yet, returning empty array")
            return []
        }
        
        var chatList: [Chat] = []
        let query = chats.order(chatUpdatedAt.desc)
        
        do {
            for row in try db.prepare(query) {
                // Safely unwrap required values
                guard let id = UUID(uuidString: row[chatId]),
                      let provider = LLMProvider(rawValue: row[chatLLMProvider]) else {
                    print("Warning: Skipping chat with invalid data")
                    continue
                }
                
                // Handle date values with error handling
                let createdAt: Date
                let updatedAt: Date
                
                do {
                    createdAt = row[chatCreatedAt]
                    updatedAt = row[chatUpdatedAt]
                } catch {
                    print("Warning: Failed to parse dates for chat \(id), using current date")
                    createdAt = Date()
                    updatedAt = Date()
                }
                
                let chat = Chat(
                    id: id,
                    title: row[chatTitle],
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    llmProvider: provider,
                    modelName: row[chatModelName],
                    isArchived: row[chatIsArchived],
                    messageCount: row[chatMessageCount],
                    lastMessagePreview: row[chatLastMessagePreview]
                )
                chatList.append(chat)
            }
        } catch {
            // If the table doesn't exist or is empty, return empty array
            print("Error loading chats: \(error)")
            return []
        }
        
        return chatList
    }
    
    func deleteChat(id: UUID) async throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        let chatToDelete = chats.filter(chatId == id.uuidString)
        try db.run(chatToDelete.delete())
    }
    
    private func loadChats(byIds chatIds: [String]) async throws -> [Chat] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        var chatList: [Chat] = []
        
        for id in chatIds {
            let query = chats.filter(chatId == id).limit(1)
            
            for row in try db.prepare(query) {
                guard let uuid = UUID(uuidString: row[chatId]),
                      let provider = LLMProvider(rawValue: row[chatLLMProvider]) else {
                    continue
                }
                
                let chat = Chat(
                    id: uuid,
                    title: row[chatTitle],
                    createdAt: row[chatCreatedAt],
                    updatedAt: row[chatUpdatedAt],
                    llmProvider: provider,
                    modelName: row[chatModelName],
                    isArchived: row[chatIsArchived],
                    messageCount: row[chatMessageCount],
                    lastMessagePreview: row[chatLastMessagePreview]
                )
                chatList.append(chat)
            }
        }
        
        return chatList
    }
    
    func searchChats(query: String) async throws -> [Chat] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        // Use LIKE query for search
        var chatList: [Chat] = []
        let searchQuery = chats.filter(chatTitle.like("%\(query)%") || 
                                     chatLastMessagePreview.like("%\(query)%"))
                               .order(chatUpdatedAt.desc)
        
        do {
            for row in try db.prepare(searchQuery) {
                // Safely unwrap required values
                guard let id = UUID(uuidString: row[chatId]),
                      let provider = LLMProvider(rawValue: row[chatLLMProvider]) else {
                    print("Warning: Skipping chat with invalid data")
                    continue
                }
                
                let chat = Chat(
                    id: id,
                    title: row[chatTitle],
                    createdAt: row[chatCreatedAt],
                    updatedAt: row[chatUpdatedAt],
                    llmProvider: provider,
                    modelName: row[chatModelName],
                    isArchived: row[chatIsArchived],
                    messageCount: row[chatMessageCount],
                    lastMessagePreview: row[chatLastMessagePreview]
                )
                chatList.append(chat)
            }
        } catch {
            // If search fails, return empty array
            print("Error searching chats: \(error)")
            return []
        }
        
        return chatList
    }
    
    // MARK: - Enhanced Search Methods
    
    func searchChatsWithFullText(
        query: String,
        provider: LLMProvider? = nil,
        isArchived: Bool? = nil,
        dateRange: (from: Date, to: Date)? = nil
    ) async throws -> [Chat] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        // Use regular search and add provider/archive filtering
        var results = try await searchChats(query: query)
        
        // Apply additional filters
        if let provider = provider {
            results = results.filter { $0.llmProvider == provider }
        }
        
        if let isArchived = isArchived {
            results = results.filter { $0.isArchived == isArchived }
        }
        
        if let dateRange = dateRange {
            results = results.filter { 
                $0.createdAt >= dateRange.from && $0.createdAt <= dateRange.to 
            }
        }
        
        return results
    }
    
    func searchMessagesWithFullText(
        query: String,
        chatId: UUID? = nil,
        isUser: Bool? = nil,
        dateRange: (from: Date, to: Date)? = nil
    ) async throws -> [Message] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        // Use regular search and add filtering
        var results = try await searchMessages(query: query, in: chatId)
        
        // Apply additional filters
        if let isUser = isUser {
            results = results.filter { $0.isUser == isUser }
        }
        
        if let dateRange = dateRange {
            results = results.filter { 
                $0.timestamp >= dateRange.from && $0.timestamp <= dateRange.to 
            }
        }
        
        return results
    }
    
    // MARK: - Advanced Query Methods
    
    func getChatsByProvider(_ provider: LLMProvider, includeArchived: Bool = false) async throws -> [Chat] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        var query = chats.filter(chatLLMProvider == provider.rawValue)
        
        if !includeArchived {
            query = query.filter(chatIsArchived == false)
        }
        
        query = query.order(chatUpdatedAt.desc)
        
        var chatList: [Chat] = []
        
        for row in try db.prepare(query) {
            let chat = Chat(
                id: UUID(uuidString: row[chatId])!,
                title: row[chatTitle],
                createdAt: row[chatCreatedAt],
                updatedAt: row[chatUpdatedAt],
                llmProvider: LLMProvider(rawValue: row[chatLLMProvider])!,
                modelName: row[chatModelName],
                isArchived: row[chatIsArchived],
                messageCount: row[chatMessageCount],
                lastMessagePreview: row[chatLastMessagePreview]
            )
            chatList.append(chat)
        }
        
        return chatList
    }
    
    func getChatsByDateRange(from startDate: Date, to endDate: Date) async throws -> [Chat] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        let query = chats.filter(chatCreatedAt >= startDate && chatCreatedAt <= endDate)
                         .order(chatCreatedAt.desc)
        
        var chatList: [Chat] = []
        
        for row in try db.prepare(query) {
            let chat = Chat(
                id: UUID(uuidString: row[chatId])!,
                title: row[chatTitle],
                createdAt: row[chatCreatedAt],
                updatedAt: row[chatUpdatedAt],
                llmProvider: LLMProvider(rawValue: row[chatLLMProvider])!,
                modelName: row[chatModelName],
                isArchived: row[chatIsArchived],
                messageCount: row[chatMessageCount],
                lastMessagePreview: row[chatLastMessagePreview]
            )
            chatList.append(chat)
        }
        
        return chatList
    }
    
    func getMessagesByDateRange(from startDate: Date, to endDate: Date) async throws -> [Message] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        let query = messages.filter(messageTimestamp >= startDate && messageTimestamp <= endDate)
                           .order(messageTimestamp.desc)
        
        var messageList: [Message] = []
        
        for row in try db.prepare(query) {
            // Only create metadata if at least one field has a value
            let metadata: MessageMetadata?
            if row[messageModel] != nil || row[messageProvider] != nil || 
               row[messageResponseTime] != nil || row[messagePromptTokens] != nil ||
               row[messageResponseTokens] != nil || row[messageTotalTokens] != nil {
                metadata = MessageMetadata(
                    model: row[messageModel],
                    provider: row[messageProvider] != nil ? LLMProvider(rawValue: row[messageProvider]!) : nil,
                    responseTime: row[messageResponseTime],
                    promptTokens: row[messagePromptTokens],
                    responseTokens: row[messageResponseTokens],
                    totalTokens: row[messageTotalTokens]
                )
            } else {
                metadata = nil
            }
            
            let message = Message(
                id: UUID(uuidString: row[messageId])!,
                chatId: UUID(uuidString: row[messageChatId])!,
                content: row[messageContent],
                isUser: row[messageIsUser],
                timestamp: row[messageTimestamp],
                imageData: row[messageImageData],
                metadata: metadata,
                status: MessageStatus(rawValue: row[messageStatus])!,
                editedAt: row[messageEditedAt]
            )
            messageList.append(message)
        }
        
        return messageList
    }
    
    func getRecentChats(limit: Int = 10) async throws -> [Chat] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        let query = chats.filter(chatIsArchived == false)
                         .order(chatUpdatedAt.desc)
                         .limit(limit)
        
        var chatList: [Chat] = []
        
        for row in try db.prepare(query) {
            let chat = Chat(
                id: UUID(uuidString: row[chatId])!,
                title: row[chatTitle],
                createdAt: row[chatCreatedAt],
                updatedAt: row[chatUpdatedAt],
                llmProvider: LLMProvider(rawValue: row[chatLLMProvider])!,
                modelName: row[chatModelName],
                isArchived: row[chatIsArchived],
                messageCount: row[chatMessageCount],
                lastMessagePreview: row[chatLastMessagePreview]
            )
            chatList.append(chat)
        }
        
        return chatList
    }
    
    // MARK: - Message Operations
    
    func saveMessage(_ message: Message) async throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        try db.transaction {
            let insert = messages.insert(or: .replace,
                messageId <- message.id.uuidString,
                messageChatId <- message.chatId.uuidString,
                messageContent <- message.content,
                messageIsUser <- message.isUser,
                messageTimestamp <- message.timestamp,
                messageImageData <- message.imageData,
                messageStatus <- message.status.rawValue,
                messageEditedAt <- message.editedAt,
                messageModel <- message.metadata?.model,
                messageProvider <- message.metadata?.provider?.rawValue,
                messageResponseTime <- message.metadata?.responseTime,
                messagePromptTokens <- message.metadata?.promptTokens,
                messageResponseTokens <- message.metadata?.responseTokens,
                messageTotalTokens <- message.metadata?.totalTokens
            )
            
            try db.run(insert)
        }
        
        // Update chat's message count and last message preview
        await updateChatStats(chatId: message.chatId)
    }
    
    func updateMessage(_ message: Message) async throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        // First check if message exists
        let existingMessage = messages.filter(messageId == message.id.uuidString)
        let count = try db.scalar(existingMessage.count)
        
        if count > 0 {
            // Update existing message in a transaction
            try db.transaction {
                let update = existingMessage.update(
                    messageContent <- message.content,
                    messageStatus <- message.status.rawValue,
                    messageEditedAt <- message.editedAt,
                    messageModel <- message.metadata?.model,
                    messageProvider <- message.metadata?.provider?.rawValue,
                    messageResponseTime <- message.metadata?.responseTime,
                    messagePromptTokens <- message.metadata?.promptTokens,
                    messageResponseTokens <- message.metadata?.responseTokens,
                    messageTotalTokens <- message.metadata?.totalTokens
                )
                try db.run(update)
            }
        } else {
            // If message doesn't exist, save it
            try await saveMessage(message)
        }
        
        // Update chat's message count and last message preview
        await updateChatStats(chatId: message.chatId)
    }
    
    func loadMessages(for chatId: UUID) async throws -> [Message] {
        try ensureInitialized()
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        var messageList: [Message] = []
        let query = messages.filter(messageChatId == chatId.uuidString)
                           .order(messageTimestamp.asc)
        
        for row in try db.prepare(query) {
            // Only create metadata if at least one field has a value
            let metadata: MessageMetadata?
            if row[messageModel] != nil || row[messageProvider] != nil || 
               row[messageResponseTime] != nil || row[messagePromptTokens] != nil ||
               row[messageResponseTokens] != nil || row[messageTotalTokens] != nil {
                metadata = MessageMetadata(
                    model: row[messageModel],
                    provider: row[messageProvider] != nil ? LLMProvider(rawValue: row[messageProvider]!) : nil,
                    responseTime: row[messageResponseTime],
                    promptTokens: row[messagePromptTokens],
                    responseTokens: row[messageResponseTokens],
                    totalTokens: row[messageTotalTokens]
                )
            } else {
                metadata = nil
            }
            
            let message = Message(
                id: UUID(uuidString: row[messageId])!,
                chatId: UUID(uuidString: row[messageChatId])!,
                content: row[messageContent],
                isUser: row[messageIsUser],
                timestamp: row[messageTimestamp],
                imageData: row[messageImageData],
                metadata: metadata,
                status: MessageStatus(rawValue: row[messageStatus])!,
                editedAt: row[messageEditedAt]
            )
            messageList.append(message)
        }
        
        return messageList
    }
    
    /// Load recent messages for a chat with performance optimization
    func loadRecentMessages(for chatId: UUID, limit: Int = 100) async throws -> [Message] {
        try ensureInitialized()
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        var messageList: [Message] = []
        // Get the most recent messages first, then reverse to maintain chronological order
        let query = messages.filter(messageChatId == chatId.uuidString)
                           .order(messageTimestamp.desc)
                           .limit(limit)
        
        var tempList: [Message] = []
        
        for row in try db.prepare(query) {
            // Only create metadata if at least one field has a value
            let metadata: MessageMetadata?
            if row[messageModel] != nil || row[messageProvider] != nil || 
               row[messageResponseTime] != nil || row[messagePromptTokens] != nil ||
               row[messageResponseTokens] != nil || row[messageTotalTokens] != nil {
                metadata = MessageMetadata(
                    model: row[messageModel],
                    provider: row[messageProvider] != nil ? LLMProvider(rawValue: row[messageProvider]!) : nil,
                    responseTime: row[messageResponseTime],
                    promptTokens: row[messagePromptTokens],
                    responseTokens: row[messageResponseTokens],
                    totalTokens: row[messageTotalTokens]
                )
            } else {
                metadata = nil
            }
            
            let message = Message(
                id: UUID(uuidString: row[messageId])!,
                chatId: UUID(uuidString: row[messageChatId])!,
                content: row[messageContent],
                isUser: row[messageIsUser],
                timestamp: row[messageTimestamp],
                imageData: row[messageImageData],
                metadata: metadata,
                status: MessageStatus(rawValue: row[messageStatus])!,
                editedAt: row[messageEditedAt]
            )
            tempList.append(message)
        }
        
        // Reverse to maintain chronological order (oldest to newest)
        messageList = tempList.reversed()
        
        return messageList
    }
    
    func deleteMessage(id: UUID) async throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        // Get the chat ID before deleting
        let messageQuery = messages.filter(messageId == id.uuidString).limit(1)
        var chatIdToUpdate: UUID?
        
        for row in try db.prepare(messageQuery) {
            chatIdToUpdate = UUID(uuidString: row[messageChatId])
        }
        
        // Delete the message
        let messageToDelete = messages.filter(messageId == id.uuidString)
        try db.run(messageToDelete.delete())
        
        // Update chat stats
        if let chatId = chatIdToUpdate {
            await updateChatStats(chatId: chatId)
        }
    }
    
    func searchMessages(query: String, in chatId: UUID? = nil) async throws -> [Message] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        // Use LIKE query for search
        var messageList: [Message] = []
        var searchQuery = messages.filter(messageContent.like("%\(query)%"))
        
        if let chatId = chatId {
            searchQuery = searchQuery.filter(messageChatId == chatId.uuidString)
        }
        
        searchQuery = searchQuery.order(messageTimestamp.desc)
        
        for row in try db.prepare(searchQuery) {
            // Only create metadata if at least one field has a value
            let metadata: MessageMetadata?
            if row[messageModel] != nil || row[messageProvider] != nil || 
               row[messageResponseTime] != nil || row[messagePromptTokens] != nil ||
               row[messageResponseTokens] != nil || row[messageTotalTokens] != nil {
                metadata = MessageMetadata(
                    model: row[messageModel],
                    provider: row[messageProvider] != nil ? LLMProvider(rawValue: row[messageProvider]!) : nil,
                    responseTime: row[messageResponseTime],
                    promptTokens: row[messagePromptTokens],
                    responseTokens: row[messageResponseTokens],
                    totalTokens: row[messageTotalTokens]
                )
            } else {
                metadata = nil
            }
            
            let message = Message(
                id: UUID(uuidString: row[messageId])!,
                chatId: UUID(uuidString: row[messageChatId])!,
                content: row[messageContent],
                isUser: row[messageIsUser],
                timestamp: row[messageTimestamp],
                imageData: row[messageImageData],
                metadata: metadata,
                status: MessageStatus(rawValue: row[messageStatus])!,
                editedAt: row[messageEditedAt]
            )
            messageList.append(message)
        }
        
        return messageList
    }
    
    private func loadMessages(byIds messageIds: [String]) async throws -> [Message] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        var messageList: [Message] = []
        
        for id in messageIds {
            let query = messages.filter(messageId == id).limit(1)
            
            for row in try db.prepare(query) {
                // Only create metadata if at least one field has a value
                let metadata: MessageMetadata?
                if row[messageModel] != nil || row[messageProvider] != nil || 
                   row[messageResponseTime] != nil || row[messagePromptTokens] != nil ||
                   row[messageResponseTokens] != nil || row[messageTotalTokens] != nil {
                    metadata = MessageMetadata(
                        model: row[messageModel],
                        provider: row[messageProvider] != nil ? LLMProvider(rawValue: row[messageProvider]!) : nil,
                        responseTime: row[messageResponseTime],
                        promptTokens: row[messagePromptTokens],
                        responseTokens: row[messageResponseTokens],
                        totalTokens: row[messageTotalTokens]
                    )
                } else {
                    metadata = nil
                }
                
                let message = Message(
                    id: UUID(uuidString: row[messageId])!,
                    chatId: UUID(uuidString: row[messageChatId])!,
                    content: row[messageContent],
                    isUser: row[messageIsUser],
                    timestamp: row[messageTimestamp],
                    imageData: row[messageImageData],
                    metadata: metadata,
                    status: MessageStatus(rawValue: row[messageStatus])!,
                    editedAt: row[messageEditedAt]
                )
                messageList.append(message)
            }
        }
        
        return messageList
    }
    
    // MARK: - Helper Methods
    
    private func checkTableExists(db: Connection, tableName: String) async throws -> Bool {
        let query = "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?"
        let count = try db.scalar(query, tableName) as! Int64
        return count > 0
    }
    
    private func validateDatabaseFile() async -> Bool {
        do {
            // Try to open a temporary connection to validate the database
            let tempDb = try Connection(databasePath)
            
            // Try a simple query to see if the database is readable
            _ = try tempDb.scalar("SELECT COUNT(*) FROM sqlite_master")
            
            // If we have tables, try to query the chats table
            if try tempDb.scalar("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='chats'") as! Int64 > 0 {
                // Try to count chats - this will fail if date format is wrong
                _ = try tempDb.prepare("SELECT * FROM chats LIMIT 1")
            }
            
            return true
        } catch {
            print("Database validation failed: \(error)")
            return false
        }
    }
    
    private func recoverFromDatabaseError() async {
        print("Attempting to recover from database error...")
        
        // Close any existing connection
        db = nil
        
        // Remove the corrupted database
        try? FileManager.default.removeItem(atPath: databasePath)
        try? FileManager.default.removeItem(atPath: databasePath + "-wal")
        try? FileManager.default.removeItem(atPath: databasePath + "-shm")
        
        // Try to reinitialize with a fresh database
        do {
            db = try Connection(databasePath)
            
            // Create fresh tables
            if let db = db {
                try DatabaseSchema.createTables(db: db)
                print("Successfully created fresh database")
            }
        } catch {
            print("Failed to recover database: \(error)")
        }
    }
    
    private func updateChatStats(chatId: UUID) async {
        guard let db = db else { return }
        
        do {
            try db.transaction {
                // Count messages in this chat
                let messageCount = try db.scalar(messages.filter(messageChatId == chatId.uuidString).count)
                
                // Get the latest message for preview
                let latestMessageQuery = messages.filter(messageChatId == chatId.uuidString)
                                               .order(messageTimestamp.desc)
                                               .limit(1)
                
                var lastMessagePreview: String?
                for row in try db.prepare(latestMessageQuery) {
                    let content = row[messageContent]
                    lastMessagePreview = String(content.prefix(100))
                }
                
                // Get chat title
                var chatTitle = ""
                let chatQuery = chats.filter(self.chatId == chatId.uuidString).limit(1)
                for row in try db.prepare(chatQuery) {
                    chatTitle = row[self.chatTitle]
                }
                
                // Update the chat
                let chatToUpdate = chats.filter(self.chatId == chatId.uuidString)
                try db.run(chatToUpdate.update(
                    chatMessageCount <- messageCount,
                    chatLastMessagePreview <- lastMessagePreview,
                    chatUpdatedAt <- Date()
                ))
            }
        } catch {
            print("Error updating chat stats: \(error)")
        }
    }
    
    // MARK: - Statistics
    
    func getChatStatistics() async throws -> ChatStatistics {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        let totalChats = try db.scalar(chats.count)
        let archivedChats = try db.scalar(chats.filter(chatIsArchived == true).count)
        let activeChats = totalChats - archivedChats
        
        let totalMessages = try db.scalar(messages.count)
        let avgMessagesPerChat = totalChats > 0 ? Double(totalMessages) / Double(totalChats) : 0.0
        
        // Get chats by provider
        var chatsByProvider: [LLMProvider: Int] = [:]
        for provider in LLMProvider.allCases {
            let count = try db.scalar(chats.filter(chatLLMProvider == provider.rawValue).count)
            if count > 0 {
                chatsByProvider[provider] = count
            }
        }
        
        return ChatStatistics(
            totalChats: totalChats,
            activeCount: activeChats,
            archivedCount: archivedChats,
            chatsByProvider: chatsByProvider,
            averageMessagesPerChat: avgMessagesPerChat
        )
    }
    
    // MARK: - Database Maintenance
    
    func vacuum() async throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        try db.execute("VACUUM")
    }
    
    func getDBSize() async throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: databasePath)
        return attributes[.size] as? Int64 ?? 0
    }
    
    func deleteAllData() async throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        try db.run(messages.delete())
        try db.run(chats.delete())
    }
    
    // MARK: - Database Analytics and Performance
    
    func getDatabaseStats() async throws -> DatabaseStats {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabaseSchema.QueryOptimizer.getDatabaseStats(db: db)
    }
    
    func analyzeQuery(_ query: String) async throws -> [String: Any] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabaseSchema.QueryOptimizer.analyzeQuery(query, db: db)
    }
    
    func optimizeDatabase() async throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        // Analyze tables
        try db.execute("ANALYZE")
        
        // Vacuum database
        try await vacuum()
        
        // Reindex for performance
        try db.execute("REINDEX")
    }
    
    func getIndexUsageStats() async throws -> [String: Any] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        var stats: [String: Any] = [:]
        
        // Get index information
        let indexQuery = "SELECT name, sql FROM sqlite_master WHERE type='index' AND sql IS NOT NULL"
        var indexes: [[String: Any]] = []
        
        for row in try db.prepare(indexQuery) {
            indexes.append([
                "name": row[0] as? String ?? "",
                "sql": row[1] as? String ?? ""
            ])
        }
        
        stats["indexes"] = indexes
        stats["indexCount"] = indexes.count
        
        return stats
    }
    
    func getTableSizes() async throws -> [String: Int64] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        var tableSizes: [String: Int64] = [:]
        
        // Get page counts for each table
        let tables = ["chats", "messages", "settings", "chat_stats"]
        
        for tableName in tables {
            do {
                let pageCountQuery = "SELECT COUNT(*) FROM pragma_page_count('\(tableName)')"
                let pageCount = try db.scalar(pageCountQuery) as? Int64 ?? 0
                let pageSize = try db.scalar("PRAGMA page_size") as? Int64 ?? 4096
                tableSizes[tableName] = pageCount * pageSize
            } catch {
                // Table might not exist yet
                tableSizes[tableName] = 0
            }
        }
        
        return tableSizes
    }
    
    func getQueryPerformanceMetrics() async throws -> [String: Any] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        var metrics: [String: Any] = [:]
        
        // Get SQLite version and compile options
        let sqliteVersion = try db.scalar("SELECT sqlite_version()") as! String
        metrics["sqliteVersion"] = sqliteVersion
        
        // Get cache hit ratio
        let cacheHitRatio = try getCacheHitRatio(db: db)
        metrics["cacheHitRatio"] = cacheHitRatio
        
        // Get memory usage
        let memoryUsed = try db.scalar("PRAGMA cache_size") as! Int
        metrics["memoryCacheSizePages"] = memoryUsed
        
        return metrics
    }
    
    private func getCacheHitRatio(db: Connection) throws -> Double {
        let cacheHits = try db.scalar("SELECT value FROM pragma_stats WHERE name='cache_hits'") as? Int ?? 0
        let cacheMisses = try db.scalar("SELECT value FROM pragma_stats WHERE name='cache_misses'") as? Int ?? 0
        
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0.0 }
        
        return Double(cacheHits) / Double(total)
    }
    
    // MARK: - Migration Management
    
    func getCurrentSchemaVersion() async throws -> Int {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabaseMigrator.shared.getCurrentSchemaVersion(db: db)
    }
    
    func validateDatabaseSchema() async throws -> SchemaValidationResult {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try await DatabaseMigrator.shared.validateSchema(db: db)
    }
    
    func getMigrationHistory() async throws -> [DatabaseMigrator.MigrationStatus] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try await DatabaseMigrator.shared.getMigrationHistory(db: db)
    }
    
    func getBackupList() async throws -> [(url: URL, size: Int64, date: Date)] {
        return try await DatabaseMigrator.shared.getBackupList()
    }
    
    func createDatabaseBackup() async throws -> String {
        guard let db = db else { throw DatabaseError.connectionFailed }
        let currentVersion = try await getCurrentSchemaVersion()
        return try await DatabaseMigrator.shared.createBackup(db: db, version: currentVersion)
    }
    
    func restoreFromBackup(backupPath: String) async throws {
        try await DatabaseMigrator.shared.restoreFromBackup(backupPath: backupPath)
        
        // Reinitialize database connection after restore
        await initializeDatabase()
    }
    
    // MARK: - Database Security Management
    
    func enableDatabaseEncryption() async throws {
        // Close current connection
        db = nil
        
        // Check if database is already encrypted
        if DatabaseSecurity.shared.isDatabaseEncrypted(at: databasePath) {
            // Already encrypted, just update settings
            Defaults[.enableDataEncryption] = true
            await initializeDatabase()
            return
        }
        
        // Encrypt existing database
        try DatabaseSecurity.shared.encryptExistingDatabase(at: databasePath)
        
        // Update settings
        Defaults[.enableDataEncryption] = true
        
        // Reinitialize with encryption
        await initializeDatabase()
    }
    
    func disableDatabaseEncryption() async throws {
        // Close current connection
        db = nil
        
        // Check if database is encrypted
        if !DatabaseSecurity.shared.isDatabaseEncrypted(at: databasePath) {
            // Already unencrypted, just update settings
            Defaults[.enableDataEncryption] = false
            await initializeDatabase()
            return
        }
        
        // Decrypt existing database
        try DatabaseSecurity.shared.decryptDatabase(at: databasePath)
        
        // Update settings
        Defaults[.enableDataEncryption] = false
        
        // Reinitialize without encryption
        await initializeDatabase()
    }
    
    func rotateEncryptionKey() async throws {
        guard Defaults[.enableDataEncryption] else {
            throw DatabaseSecurityError.invalidEncryptionKey
        }
        
        // Close current connection
        db = nil
        
        // Rotate the key
        try DatabaseSecurity.shared.rotateEncryptionKey(at: databasePath)
        
        // Record rotation
        try DatabaseSecurity.shared.recordKeyRotation()
        
        // Reinitialize connection
        await initializeDatabase()
    }
    
    func validateDatabaseSecurity() async throws -> SecurityValidationResult {
        return try DatabaseSecurity.shared.validateDatabaseSecurity(at: databasePath)
    }
    
    func isDatabaseEncrypted() -> Bool {
        return DatabaseSecurity.shared.isDatabaseEncrypted(at: databasePath)
    }
    
    func shouldRotateEncryptionKey() -> Bool {
        guard Defaults[.enableDataEncryption] else { return false }
        return DatabaseSecurity.shared.shouldRotateKey()
    }
    
    // MARK: - Performance Optimization Methods
    
    func loadChatsPaginated(
        options: DatabasePerformanceOptimizer.PaginationOptions = .default,
        filters: ChatFilters = ChatFilters()
    ) async throws -> DatabasePerformanceOptimizer.PaginatedResult<Chat> {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabasePerformanceOptimizer.shared.optimizeChatsQuery(
            db: db,
            options: options,
            filters: filters
        )
    }
    
    func loadMessagesPaginated(
        for chatId: UUID,
        options: DatabasePerformanceOptimizer.PaginationOptions = .default,
        filters: MessageFilters = MessageFilters()
    ) async throws -> DatabasePerformanceOptimizer.PaginatedResult<Message> {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabasePerformanceOptimizer.shared.optimizeMessagesQuery(
            db: db,
            chatId: chatId,
            options: options,
            filters: filters
        )
    }
    
    func batchSaveChats(_ chats: [Chat]) async throws -> DatabasePerformanceOptimizer.BatchOperationResult {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabasePerformanceOptimizer.shared.batchInsertChats(db: db, chats: chats)
    }
    
    func batchSaveMessages(_ messages: [Message]) async throws -> DatabasePerformanceOptimizer.BatchOperationResult {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabasePerformanceOptimizer.shared.batchInsertMessages(db: db, messages: messages)
    }
    
    func batchDeleteMessages(_ messageIds: [UUID]) async throws -> DatabasePerformanceOptimizer.BatchOperationResult {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabasePerformanceOptimizer.shared.batchDeleteMessages(db: db, messageIds: messageIds)
    }
    
    func archiveOldData(
        options: DatabasePerformanceOptimizer.ArchivalOptions = .default
    ) async throws -> ArchivalResult {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabasePerformanceOptimizer.shared.archiveOldChatData(db: db, options: options)
    }
    
    func cleanupDatabase() async throws -> CleanupResult {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabasePerformanceOptimizer.shared.cleanupOrphanedData(db: db)
    }
    
    func getPerformanceMetrics() async throws -> PerformanceMetrics {
        guard let db = db else { throw DatabaseError.connectionFailed }
        return try DatabasePerformanceOptimizer.shared.getPerformanceMetrics(db: db)
    }
    
    func optimizeForPerformance() async throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        
        // Run ANALYZE to update statistics
        try db.execute("ANALYZE")
        
        // Rebuild indexes if fragmentation is high
        let metrics = try await getPerformanceMetrics()
        if metrics.fragmentationLevel > 15.0 {
            try db.execute("REINDEX")
        }
        
        // Vacuum if database is large and fragmented
        if metrics.databaseSizeMB > 100 && metrics.fragmentationLevel > 10.0 {
            try await vacuum()
        }
        
        // Clean up orphaned data
        _ = try await cleanupDatabase()
    }
    
    func schedulePerformanceMaintenance() async {
        // Schedule maintenance based on user settings
        let maintenanceInterval = Defaults[.performanceMaintenanceInterval]
        let lastMaintenance = Defaults[.lastPerformanceMaintenance]
        
        let shouldRunMaintenance = Date().timeIntervalSince(lastMaintenance) > maintenanceInterval
        
        if shouldRunMaintenance {
            do {
                try await optimizeForPerformance()
                Defaults[.lastPerformanceMaintenance] = Date()
                print("Performance maintenance completed successfully")
            } catch {
                print("Performance maintenance failed: \(error)")
            }
        }
    }
    
    // MARK: - Shutdown and Cleanup
    
    /// Gracefully shuts down the database connection
    /// Ensures all pending operations complete before closing
    func shutdown() async {
        guard let connection = db else { return }
        
        print("🔄 Shutting down database connection...")
        
        do {
            // Flush any pending WAL data
            try connection.execute("PRAGMA wal_checkpoint(FULL)")
            
            // Optimize database before closing
            try connection.execute("PRAGMA optimize")
            
            // Close connection
            self.db = nil
            
            print("✅ Database connection closed gracefully")
        } catch {
            print("⚠️ Error during database shutdown: \(error)")
            // Force close anyway
            self.db = nil
        }
    }
    
    /// Force close the database connection immediately
    /// Used during emergency shutdown
    func forceClose() {
        print("⚠️ Force closing database connection")
        db = nil
    }
}

// MARK: - Database Errors

enum DatabaseError: Error, LocalizedError {
    case connectionFailed
    case tableCreationFailed
    case insertFailed
    case queryFailed
    case deleteFailed
    case migrationFailed
    case notInitialized
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to database"
        case .tableCreationFailed:
            return "Failed to create database tables"
        case .insertFailed:
            return "Failed to insert data"
        case .queryFailed:
            return "Failed to query data"
        case .deleteFailed:
            return "Failed to delete data"
        case .migrationFailed:
            return "Failed to migrate database"
        case .notInitialized:
            return "Database manager not initialized. Call DatabaseManager.shared.initialize() before use."
        }
    }
}

// MARK: - Chat Statistics

struct ChatStatistics {
    let totalChats: Int
    let activeCount: Int
    let archivedCount: Int
    let chatsByProvider: [LLMProvider: Int]
    let averageMessagesPerChat: Double
}