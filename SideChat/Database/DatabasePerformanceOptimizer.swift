import Foundation
import SQLite
import Defaults

// MARK: - Database Performance Optimizer

/// DatabasePerformanceOptimizer provides advanced performance optimizations for large chat histories
/// Includes pagination, batch operations, connection pooling, and data archival strategies

class DatabasePerformanceOptimizer {
    static let shared = DatabasePerformanceOptimizer()
    
    private init() {}
    
    // MARK: - Pagination Support
    
    struct PaginationOptions {
        let offset: Int
        let limit: Int
        let sortOrder: SortOrder
        
        enum SortOrder {
            case newest
            case oldest
            case relevance
        }
        
        static let `default` = PaginationOptions(offset: 0, limit: 50, sortOrder: .newest)
    }
    
    struct PaginatedResult<T> {
        let items: [T]
        let totalCount: Int
        let hasMore: Bool
        let nextOffset: Int?
        
        var isEmpty: Bool { items.isEmpty }
        var currentCount: Int { items.count }
    }
    
    // MARK: - Batch Operations
    
    struct BatchOperationResult {
        let successCount: Int
        let failureCount: Int
        let errors: [Error]
        let executionTimeMs: Double
        
        var isFullSuccess: Bool { failureCount == 0 }
        var totalOperations: Int { successCount + failureCount }
    }
    
    // MARK: - Optimized Chat Queries
    
    func optimizeChatsQuery(
        db: Connection,
        options: PaginationOptions = .default,
        filters: ChatFilters = ChatFilters()
    ) throws -> PaginatedResult<Chat> {
        
        let chatsTable = DatabaseSchema.Tables.chats
        var query = chatsTable.select(*)
        
        // Apply filters using SQLite.swift expressions
        if let provider = filters.provider {
            query = query.filter(DatabaseSchema.Tables.chatLLMProvider == provider.rawValue)
        }
        
        if let isArchived = filters.isArchived {
            query = query.filter(DatabaseSchema.Tables.chatIsArchived == isArchived)
        }
        
        if let searchTerm = filters.searchTerm, !searchTerm.isEmpty {
            let searchPattern = "%\(searchTerm)%"
            query = query.filter(
                DatabaseSchema.Tables.chatTitle.like(searchPattern) ||
                DatabaseSchema.Tables.chatLastMessagePreview.like(searchPattern)
            )
        }
        
        if let dateRange = filters.dateRange {
            query = query.filter(
                DatabaseSchema.Tables.chatCreatedAt >= dateRange.from &&
                DatabaseSchema.Tables.chatCreatedAt <= dateRange.to
            )
        }
        
        // Get total count
        let totalCount = try db.scalar(query.count)
        
        // Apply sorting
        switch options.sortOrder {
        case .newest:
            query = query.order(DatabaseSchema.Tables.chatUpdatedAt.desc)
        case .oldest:
            query = query.order(DatabaseSchema.Tables.chatCreatedAt.asc)
        case .relevance:
            query = query.order(DatabaseSchema.Tables.chatUpdatedAt.desc)
        }
        
        // Apply pagination
        query = query.limit(options.limit, offset: options.offset)
        
        // Execute query and build results
        var chats: [Chat] = []
        for row in try db.prepare(query) {
            let chat = Chat(
                id: UUID(uuidString: try row.get(DatabaseSchema.Tables.chatId))!,
                title: try row.get(DatabaseSchema.Tables.chatTitle),
                createdAt: try row.get(DatabaseSchema.Tables.chatCreatedAt),
                updatedAt: try row.get(DatabaseSchema.Tables.chatUpdatedAt),
                llmProvider: LLMProvider(rawValue: try row.get(DatabaseSchema.Tables.chatLLMProvider))!,
                modelName: try row.get(DatabaseSchema.Tables.chatModelName),
                isArchived: try row.get(DatabaseSchema.Tables.chatIsArchived),
                messageCount: try row.get(DatabaseSchema.Tables.chatMessageCount),
                lastMessagePreview: try row.get(DatabaseSchema.Tables.chatLastMessagePreview)
            )
            chats.append(chat)
        }
        
        let hasMore = options.offset + options.limit < totalCount
        let nextOffset = hasMore ? options.offset + options.limit : nil
        
        return PaginatedResult(
            items: chats,
            totalCount: totalCount,
            hasMore: hasMore,
            nextOffset: nextOffset
        )
    }
    
    func optimizeMessagesQuery(
        db: Connection,
        chatId: UUID,
        options: PaginationOptions = .default,
        filters: MessageFilters = MessageFilters()
    ) throws -> PaginatedResult<Message> {
        
        let messagesTable = DatabaseSchema.Tables.messages
        var query = messagesTable.select(*).filter(DatabaseSchema.Tables.messageChatId == chatId.uuidString)
        
        // Apply filters
        if let isUser = filters.isUser {
            query = query.filter(DatabaseSchema.Tables.messageIsUser == isUser)
        }
        
        if let status = filters.status {
            query = query.filter(DatabaseSchema.Tables.messageStatus == status.rawValue)
        }
        
        if let searchTerm = filters.searchTerm, !searchTerm.isEmpty {
            query = query.filter(DatabaseSchema.Tables.messageContent.like("%\(searchTerm)%"))
        }
        
        if let dateRange = filters.dateRange {
            query = query.filter(
                DatabaseSchema.Tables.messageTimestamp >= dateRange.from &&
                DatabaseSchema.Tables.messageTimestamp <= dateRange.to
            )
        }
        
        // Get total count
        let totalCount = try db.scalar(query.count)
        
        // Apply sorting
        switch options.sortOrder {
        case .newest:
            query = query.order(DatabaseSchema.Tables.messageTimestamp.desc)
        case .oldest:
            query = query.order(DatabaseSchema.Tables.messageTimestamp.asc)
        case .relevance:
            query = query.order(DatabaseSchema.Tables.messageTimestamp.desc)
        }
        
        // Apply pagination
        query = query.limit(options.limit, offset: options.offset)
        
        // Execute query and build results
        var messages: [Message] = []
        for row in try db.prepare(query) {
            let providerString: String? = try row.get(DatabaseSchema.Tables.messageProvider)
            let metadata = MessageMetadata(
                model: try row.get(DatabaseSchema.Tables.messageModel),
                provider: providerString.flatMap { LLMProvider(rawValue: $0) },
                responseTime: try row.get(DatabaseSchema.Tables.messageResponseTime),
                promptTokens: try row.get(DatabaseSchema.Tables.messagePromptTokens),
                responseTokens: try row.get(DatabaseSchema.Tables.messageResponseTokens),
                totalTokens: try row.get(DatabaseSchema.Tables.messageTotalTokens)
            )
            
            let message = Message(
                id: UUID(uuidString: try row.get(DatabaseSchema.Tables.messageId))!,
                chatId: UUID(uuidString: try row.get(DatabaseSchema.Tables.messageChatId))!,
                content: try row.get(DatabaseSchema.Tables.messageContent),
                isUser: try row.get(DatabaseSchema.Tables.messageIsUser),
                timestamp: try row.get(DatabaseSchema.Tables.messageTimestamp),
                imageData: try row.get(DatabaseSchema.Tables.messageImageData),
                metadata: metadata,
                status: MessageStatus(rawValue: try row.get(DatabaseSchema.Tables.messageStatus))!,
                editedAt: try row.get(DatabaseSchema.Tables.messageEditedAt)
            )
            messages.append(message)
        }
        
        let hasMore = options.offset + options.limit < totalCount
        let nextOffset = hasMore ? options.offset + options.limit : nil
        
        return PaginatedResult(
            items: messages,
            totalCount: totalCount,
            hasMore: hasMore,
            nextOffset: nextOffset
        )
    }
    
    // MARK: - Batch Operations
    
    func batchInsertChats(
        db: Connection,
        chats: [Chat],
        batchSize: Int = 100
    ) throws -> BatchOperationResult {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var successCount = 0
        var errors: [Error] = []
        
        // Process in batches to avoid memory issues
        for batch in chats.chunked(into: batchSize) {
            do {
                try db.transaction {
                    for chat in batch {
                        try db.run(DatabaseSchema.Tables.chats.insert(or: .replace,
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
                        successCount += 1
                    }
                }
            } catch {
                errors.append(error)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000
        
        return BatchOperationResult(
            successCount: successCount,
            failureCount: chats.count - successCount,
            errors: errors,
            executionTimeMs: executionTime
        )
    }
    
    func batchInsertMessages(
        db: Connection,
        messages: [Message],
        batchSize: Int = 200
    ) throws -> BatchOperationResult {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var successCount = 0
        var errors: [Error] = []
        
        for batch in messages.chunked(into: batchSize) {
            do {
                try db.transaction {
                    for message in batch {
                        try db.run(DatabaseSchema.Tables.messages.insert(or: .replace,
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
                        successCount += 1
                    }
                }
            } catch {
                errors.append(error)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000
        
        return BatchOperationResult(
            successCount: successCount,
            failureCount: messages.count - successCount,
            errors: errors,
            executionTimeMs: executionTime
        )
    }
    
    func batchDeleteMessages(
        db: Connection,
        messageIds: [UUID],
        batchSize: Int = 500
    ) throws -> BatchOperationResult {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var successCount = 0
        var errors: [Error] = []
        
        for batch in messageIds.chunked(into: batchSize) {
            do {
                let messageIdsStrings = batch.map { $0.uuidString }
                let query = DatabaseSchema.Tables.messages.filter(messageIdsStrings.contains(DatabaseSchema.Tables.messageId))
                try db.run(query.delete())
                successCount += batch.count
            } catch {
                errors.append(error)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000
        
        return BatchOperationResult(
            successCount: successCount,
            failureCount: messageIds.count - successCount,
            errors: errors,
            executionTimeMs: executionTime
        )
    }
    
    // MARK: - Data Archival and Cleanup
    
    struct ArchivalOptions {
        let olderThanDays: Int
        let keepRecentMessagesCount: Int
        let deleteImages: Bool
        let compressContent: Bool
        
        static let `default` = ArchivalOptions(
            olderThanDays: 90,
            keepRecentMessagesCount: 100,
            deleteImages: true,
            compressContent: true
        )
    }
    
    func archiveOldChatData(
        db: Connection,
        options: ArchivalOptions = .default
    ) throws -> ArchivalResult {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(options.olderThanDays * 24 * 60 * 60))
        
        var archivedChats = 0
        var archivedMessages = 0
        var freedSpaceBytes: Int64 = 0
        
        try db.transaction {
            // Get old chats
            let oldChatsQuery = DatabaseSchema.Tables.chats
                .filter(DatabaseSchema.Tables.chatUpdatedAt < cutoffDate && DatabaseSchema.Tables.chatIsArchived == false)
            
            for chatRow in try db.prepare(oldChatsQuery) {
                let chatId = try chatRow.get(DatabaseSchema.Tables.chatId)
                
                // Archive old messages in this chat
                if options.keepRecentMessagesCount > 0 {
                    let oldMessagesQuery = DatabaseSchema.Tables.messages
                        .filter(DatabaseSchema.Tables.messageChatId == chatId && DatabaseSchema.Tables.messageTimestamp < cutoffDate)
                        .order(DatabaseSchema.Tables.messageTimestamp.desc)
                        .limit(-1, offset: options.keepRecentMessagesCount)
                    
                    for messageRow in try db.prepare(oldMessagesQuery) {
                        let messageId = try messageRow.get(DatabaseSchema.Tables.messageId)
                        
                        if options.deleteImages {
                            if let imageData: Data = try messageRow.get(DatabaseSchema.Tables.messageImageData) {
                                freedSpaceBytes += Int64(imageData.count)
                            }
                        }
                        
                        if options.compressContent {
                            // Compress content by truncating
                            let content = try messageRow.get(DatabaseSchema.Tables.messageContent)
                            if content.count > 500 {
                                let compressedContent = String(content.prefix(500)) + "...[truncated]"
                                try db.run(DatabaseSchema.Tables.messages
                                    .filter(DatabaseSchema.Tables.messageId == messageId)
                                    .update(
                                        DatabaseSchema.Tables.messageContent <- compressedContent,
                                        DatabaseSchema.Tables.messageImageData <- nil
                                    ))
                            }
                        } else {
                            try db.run(DatabaseSchema.Tables.messages
                                .filter(DatabaseSchema.Tables.messageId == messageId)
                                .delete())
                        }
                        
                        archivedMessages += 1
                    }
                }
                
                // Mark chat as archived
                try db.run(DatabaseSchema.Tables.chats
                    .filter(DatabaseSchema.Tables.chatId == chatId)
                    .update(DatabaseSchema.Tables.chatIsArchived <- true))
                
                archivedChats += 1
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000
        
        return ArchivalResult(
            archivedChats: archivedChats,
            archivedMessages: archivedMessages,
            freedSpaceBytes: freedSpaceBytes,
            executionTimeMs: executionTime
        )
    }
    
    func cleanupOrphanedData(db: Connection) throws -> CleanupResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var deletedRecords = 0
        var freedSpaceBytes: Int64 = 0
        
        try db.transaction {
            // Delete orphaned messages
            let orphanedMessagesQuery = """
                SELECT m.id, 
                       CASE WHEN m.image_data IS NOT NULL THEN LENGTH(m.image_data) ELSE 0 END +
                       LENGTH(m.content) as size
                FROM messages m 
                LEFT JOIN chats c ON m.chat_id = c.id 
                WHERE c.id IS NULL
            """
            
            for row in try db.prepare(orphanedMessagesQuery) {
                let size = row[1] as! Int64
                freedSpaceBytes += size
                deletedRecords += 1
            }
            
            // Delete orphaned messages
            try db.execute("""
                DELETE FROM messages 
                WHERE chat_id NOT IN (SELECT id FROM chats)
            """)
            
            // Rebuild FTS tables
            try db.execute("INSERT INTO chats_fts(chats_fts) VALUES('rebuild')")
            try db.execute("INSERT INTO messages_fts(messages_fts) VALUES('rebuild')")
            
            // Update chat statistics
            try db.execute("""
                UPDATE chats SET message_count = (
                    SELECT COUNT(*) FROM messages WHERE chat_id = chats.id
                )
            """)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000
        
        return CleanupResult(
            deletedRecords: deletedRecords,
            freedSpaceBytes: freedSpaceBytes,
            executionTimeMs: executionTime
        )
    }
    
    // MARK: - Performance Monitoring
    
    func getPerformanceMetrics(db: Connection) throws -> PerformanceMetrics {
        let dbSize = try getDatabaseSize(db: db)
        let chatCount = try db.scalar(DatabaseSchema.Tables.chats.count)
        let messageCount = try db.scalar(DatabaseSchema.Tables.messages.count)
        
        // Measure query performance
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try db.scalar(DatabaseSchema.Tables.chats.filter(DatabaseSchema.Tables.chatIsArchived == false).count)
        let chatQueryTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        let messageStartTime = CFAbsoluteTimeGetCurrent()
        _ = try db.scalar(DatabaseSchema.Tables.messages.count)
        let messageQueryTime = (CFAbsoluteTimeGetCurrent() - messageStartTime) * 1000
        
        return PerformanceMetrics(
            databaseSizeBytes: dbSize,
            chatCount: chatCount,
            messageCount: messageCount,
            averageChatQueryTimeMs: chatQueryTime,
            averageMessageQueryTimeMs: messageQueryTime,
            indexCount: try getIndexCount(db: db),
            fragmentationLevel: try getFragmentationLevel(db: db)
        )
    }
    
    private func getDatabaseSize(db: Connection) throws -> Int64 {
        let pageCount = try db.scalar("PRAGMA page_count") as! Int64
        let pageSize = try db.scalar("PRAGMA page_size") as! Int64
        return pageCount * pageSize
    }
    
    private func getIndexCount(db: Connection) throws -> Int {
        return try db.scalar("SELECT COUNT(*) FROM sqlite_master WHERE type='index'") as! Int
    }
    
    private func getFragmentationLevel(db: Connection) throws -> Double {
        let pageCount = try db.scalar("PRAGMA page_count") as! Double
        let freelist = try db.scalar("PRAGMA freelist_count") as! Double
        return (freelist / pageCount) * 100.0
    }
}

// MARK: - Supporting Types

struct ChatFilters {
    let provider: LLMProvider?
    let isArchived: Bool?
    let searchTerm: String?
    let dateRange: (from: Date, to: Date)?
    
    init(
        provider: LLMProvider? = nil,
        isArchived: Bool? = nil,
        searchTerm: String? = nil,
        dateRange: (from: Date, to: Date)? = nil
    ) {
        self.provider = provider
        self.isArchived = isArchived
        self.searchTerm = searchTerm
        self.dateRange = dateRange
    }
}

struct MessageFilters {
    let isUser: Bool?
    let status: MessageStatus?
    let searchTerm: String?
    let dateRange: (from: Date, to: Date)?
    
    init(
        isUser: Bool? = nil,
        status: MessageStatus? = nil,
        searchTerm: String? = nil,
        dateRange: (from: Date, to: Date)? = nil
    ) {
        self.isUser = isUser
        self.status = status
        self.searchTerm = searchTerm
        self.dateRange = dateRange
    }
}

struct ArchivalResult {
    let archivedChats: Int
    let archivedMessages: Int
    let freedSpaceBytes: Int64
    let executionTimeMs: Double
    
    var freedSpaceMB: Double {
        return Double(freedSpaceBytes) / (1024.0 * 1024.0)
    }
}

struct CleanupResult {
    let deletedRecords: Int
    let freedSpaceBytes: Int64
    let executionTimeMs: Double
    
    var freedSpaceMB: Double {
        return Double(freedSpaceBytes) / (1024.0 * 1024.0)
    }
}

struct PerformanceMetrics {
    let databaseSizeBytes: Int64
    let chatCount: Int
    let messageCount: Int
    let averageChatQueryTimeMs: Double
    let averageMessageQueryTimeMs: Double
    let indexCount: Int
    let fragmentationLevel: Double
    
    var databaseSizeMB: Double {
        return Double(databaseSizeBytes) / (1024.0 * 1024.0)
    }
    
    var averageMessagesPerChat: Double {
        guard chatCount > 0 else { return 0.0 }
        return Double(messageCount) / Double(chatCount)
    }
    
    var isPerformanceGood: Bool {
        return averageChatQueryTimeMs < 50 && 
               averageMessageQueryTimeMs < 100 && 
               fragmentationLevel < 10.0
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}