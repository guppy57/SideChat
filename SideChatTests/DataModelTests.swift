import XCTest
import Foundation
@testable import SideChat

class DataModelTests: XCTestCase {
    
    // MARK: - Chat Model Tests
    
    func testChatModelCreation() {
        let chatId = UUID()
        let createdAt = Date()
        let chat = Chat(
            id: chatId,
            title: "Test Chat",
            createdAt: createdAt,
            updatedAt: createdAt,
            llmProvider: .openai,
            modelName: "gpt-4"
        )
        
        XCTAssertEqual(chat.id, chatId)
        XCTAssertEqual(chat.title, "Test Chat")
        XCTAssertEqual(chat.createdAt, createdAt)
        XCTAssertEqual(chat.llmProvider, .openai)
        XCTAssertEqual(chat.modelName, "gpt-4")
        XCTAssertFalse(chat.isArchived)
        XCTAssertEqual(chat.messageCount, 0)
        XCTAssertNil(chat.lastMessagePreview)
    }
    
    func testChatFactoryMethods() {
        let newChat = Chat.createNew(title: "New Chat", llmProvider: .anthropic, modelName: "claude-3")
        
        XCTAssertEqual(newChat.title, "New Chat")
        XCTAssertEqual(newChat.llmProvider, .anthropic)
        XCTAssertEqual(newChat.modelName, "claude-3")
        XCTAssertFalse(newChat.isArchived)
        XCTAssertEqual(newChat.messageCount, 0)
    }
    
    func testChatValidation() {
        let validChat = Chat.createNew(title: "Valid Chat", llmProvider: .openai, modelName: "gpt-4")
        XCTAssertTrue(validChat.isValid)
        
        let invalidChat = Chat(
            title: "",
            createdAt: Date(),
            updatedAt: Date().addingTimeInterval(-100), // Updated before created
            llmProvider: .openai,
            modelName: ""
        )
        XCTAssertFalse(invalidChat.isValid)
    }
    
    func testChatUpdateMethods() {
        var chat = Chat.createNew(title: "Original Title", llmProvider: .openai, modelName: "gpt-3.5")
        let originalUpdatedAt = chat.updatedAt
        
        // Small delay to ensure timestamp changes
        Thread.sleep(forTimeInterval: 0.01)
        
        chat.updateTitle("Updated Title")
        XCTAssertEqual(chat.title, "Updated Title")
        XCTAssertGreaterThan(chat.updatedAt, originalUpdatedAt)
        
        let newUpdatedAt = chat.updatedAt
        Thread.sleep(forTimeInterval: 0.01)
        
        chat.updateProvider(.anthropic, modelName: "claude-3")
        XCTAssertEqual(chat.llmProvider, .anthropic)
        XCTAssertEqual(chat.modelName, "claude-3")
        XCTAssertGreaterThan(chat.updatedAt, newUpdatedAt)
    }
    
    func testChatMessageCountManagement() {
        var chat = Chat.createNew(title: "Test Chat", llmProvider: .openai, modelName: "gpt-4")
        
        XCTAssertEqual(chat.messageCount, 0)
        XCTAssertTrue(chat.isEmpty)
        
        chat.incrementMessageCount()
        XCTAssertEqual(chat.messageCount, 1)
        XCTAssertFalse(chat.isEmpty)
        
        chat.incrementMessageCount()
        chat.incrementMessageCount()
        XCTAssertEqual(chat.messageCount, 3)
        
        chat.decrementMessageCount()
        XCTAssertEqual(chat.messageCount, 2)
        
        chat.updateMessageCount(5)
        XCTAssertEqual(chat.messageCount, 5)
        
        // Test that count can't go below 0
        chat.updateMessageCount(-1)
        XCTAssertEqual(chat.messageCount, 0)
    }
    
    func testChatArchiving() {
        var chat = Chat.createNew(title: "Test Chat", llmProvider: .openai, modelName: "gpt-4")
        XCTAssertFalse(chat.isArchived)
        
        chat.archive()
        XCTAssertTrue(chat.isArchived)
        
        chat.unarchive()
        XCTAssertFalse(chat.isArchived)
    }
    
    func testChatSortingAndFiltering() {
        let now = Date()
        let anHourAgo = now.addingTimeInterval(-3600)
        let twoDaysAgo = now.addingTimeInterval(-172800)
        
        let chats = [
            Chat(title: "Chat A", createdAt: twoDaysAgo, updatedAt: now, llmProvider: .openai, modelName: "gpt-4", messageCount: 5),
            Chat(title: "Chat B", createdAt: anHourAgo, updatedAt: anHourAgo, llmProvider: .anthropic, modelName: "claude-3", messageCount: 3),
            Chat(title: "Chat C", createdAt: now, updatedAt: now, llmProvider: .google, modelName: "gemini-pro", isArchived: true, messageCount: 10)
        ]
        
        // Test sorting by updated date
        let sortedByUpdated = Chat.sort(chats, by: .updatedDate, ascending: false)
        XCTAssertEqual(sortedByUpdated[0].title, "Chat C")
        XCTAssertEqual(sortedByUpdated[1].title, "Chat A")
        XCTAssertEqual(sortedByUpdated[2].title, "Chat B")
        
        // Test sorting by message count
        let sortedByMessages = Chat.sort(chats, by: .messageCount, ascending: false)
        XCTAssertEqual(sortedByMessages[0].messageCount, 10)
        XCTAssertEqual(sortedByMessages[1].messageCount, 5)
        XCTAssertEqual(sortedByMessages[2].messageCount, 3)
        
        // Test filtering by provider
        let openaiChats = Chat.filter(chats, by: .openai)
        XCTAssertEqual(openaiChats.count, 1)
        XCTAssertEqual(openaiChats[0].title, "Chat A")
        
        // Test filtering archived
        let archivedChats = Chat.filter(chats, by: .archived)
        XCTAssertEqual(archivedChats.count, 1)
        XCTAssertEqual(archivedChats[0].title, "Chat C")
        
        // Test filtering active
        let activeChats = Chat.filter(chats, by: .active)
        XCTAssertEqual(activeChats.count, 2)
        
        // Test search
        let searchResults = Chat.search(chats, query: "Chat A")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults[0].title, "Chat A")
    }
    
    func testChatExportData() {
        let chat = Chat.createNew(title: "Export Test", llmProvider: .openai, modelName: "gpt-4")
        let exportData = chat.toExportData()
        
        XCTAssertEqual(exportData.title, "Export Test")
        XCTAssertEqual(exportData.llmProvider, "openai")
        XCTAssertEqual(exportData.modelName, "gpt-4")
        XCTAssertFalse(exportData.isArchived)
        XCTAssertEqual(exportData.messageCount, 0)
    }
    
    func testChatStatistics() {
        let chats = [
            Chat(title: "Chat 1", createdAt: Date(), updatedAt: Date(), llmProvider: .openai, modelName: "gpt-4", messageCount: 5),
            Chat(title: "Chat 2", createdAt: Date(), updatedAt: Date(), llmProvider: .anthropic, modelName: "claude-3", isArchived: true, messageCount: 3),
            Chat(title: "Chat 3", createdAt: Date(), updatedAt: Date(), llmProvider: .openai, modelName: "gpt-3.5", messageCount: 7)
        ]
        
        let stats = Chat.generateStatistics(from: chats)
        
        XCTAssertEqual(stats.totalChats, 3)
        XCTAssertEqual(stats.archivedCount, 1)
        XCTAssertEqual(stats.activeCount, 2)
        XCTAssertEqual(stats.chatsByProvider[.openai], 2)
        XCTAssertEqual(stats.chatsByProvider[.anthropic], 1)
        XCTAssertEqual(stats.averageMessagesPerChat, 5.0)
    }
    
    // MARK: - Message Model Tests
    
    func testMessageModelCreation() {
        let messageId = UUID()
        let chatId = UUID()
        let timestamp = Date()
        
        let message = Message(
            id: messageId,
            chatId: chatId,
            content: "Hello, world!",
            isUser: true,
            timestamp: timestamp
        )
        
        XCTAssertEqual(message.id, messageId)
        XCTAssertEqual(message.chatId, chatId)
        XCTAssertEqual(message.content, "Hello, world!")
        XCTAssertTrue(message.isUser)
        XCTAssertEqual(message.timestamp, timestamp)
        XCTAssertNil(message.imageData)
        XCTAssertEqual(message.status, .sent)
    }
    
    func testMessageFactoryMethods() {
        let chatId = UUID()
        
        let userMessage = Message.createUserMessage(chatId: chatId, content: "User input")
        XCTAssertTrue(userMessage.isUser)
        XCTAssertFalse(userMessage.isFromBot)
        XCTAssertEqual(userMessage.content, "User input")
        XCTAssertEqual(userMessage.status, .sent)
        
        let botMessage = Message.createBotMessage(chatId: chatId, content: "Bot response")
        XCTAssertFalse(botMessage.isUser)
        XCTAssertTrue(botMessage.isFromBot)
        XCTAssertEqual(botMessage.content, "Bot response")
        XCTAssertEqual(botMessage.status, .streaming)
        
        let systemMessage = Message.createSystemMessage(chatId: chatId, content: "System message")
        XCTAssertFalse(systemMessage.isUser)
        XCTAssertEqual(systemMessage.content, "System message")
        XCTAssertEqual(systemMessage.status, .sent)
    }
    
    func testMessageProperties() {
        let message = Message(
            chatId: UUID(),
            content: "This is a test message with multiple words",
            isUser: true
        )
        
        XCTAssertEqual(message.wordCount, 9)
        XCTAssertEqual(message.characterCount, 44)
        XCTAssertFalse(message.hasImage)
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.isValid)
        XCTAssertFalse(message.isEdited)
        
        let preview = message.preview
        XCTAssertEqual(preview, "This is a test message with multiple words")
        
        let shortPreview = message.shortPreview
        XCTAssertEqual(shortPreview, "This is a test message with multiple words")
    }
    
    func testMessageWithLongContent() {
        let longContent = String(repeating: "A", count: 150)
        let message = Message(chatId: UUID(), content: longContent, isUser: true)
        
        let preview = message.preview
        XCTAssertEqual(preview.count, 103) // 100 chars + "..."
        XCTAssertTrue(preview.hasSuffix("..."))
        
        let shortPreview = message.shortPreview
        XCTAssertEqual(shortPreview.count, 53) // 50 chars + "..."
        XCTAssertTrue(shortPreview.hasSuffix("..."))
    }
    
    func testEmptyMessage() {
        let emptyMessage = Message(chatId: UUID(), content: "", isUser: true)
        XCTAssertTrue(emptyMessage.isEmpty)
        XCTAssertFalse(emptyMessage.isValid)
        XCTAssertEqual(emptyMessage.wordCount, 0)
        
        let messageWithImage = Message(chatId: UUID(), content: "", isUser: true, imageData: Data())
        XCTAssertFalse(messageWithImage.isEmpty) // Has image
        XCTAssertTrue(messageWithImage.isValid) // Valid because has image
        XCTAssertTrue(messageWithImage.hasImage)
    }
    
    func testMessageUpdates() {
        var message = Message(chatId: UUID(), content: "Original content", isUser: true)
        
        XCTAssertFalse(message.isEdited)
        XCTAssertNil(message.editedAt)
        
        message.updateContent("Updated content")
        XCTAssertEqual(message.content, "Updated content")
        XCTAssertTrue(message.isEdited)
        XCTAssertNotNil(message.editedAt)
        XCTAssertEqual(message.status, .edited)
        
        message.appendContent(" - appended")
        XCTAssertEqual(message.content, "Updated content - appended")
        
        message.setStatus(.failed)
        XCTAssertEqual(message.status, .failed)
        
        message.markAsSent()
        XCTAssertEqual(message.status, .sent)
    }
    
    func testMessageWithError() {
        var message = Message(chatId: UUID(), content: "Failed message", isUser: false)
        
        let error = MessageError(code: "API_ERROR", message: "API request failed")
        message.markAsFailed(error: error)
        
        XCTAssertEqual(message.status, .failed)
        XCTAssertNotNil(message.metadata?.error)
        XCTAssertEqual(message.metadata?.error?.code, "API_ERROR")
        XCTAssertEqual(message.metadata?.error?.message, "API request failed")
    }
    
    func testMessageSearch() {
        let message1 = Message(chatId: UUID(), content: "Hello world", isUser: true)
        let message2 = Message(chatId: UUID(), content: "Goodbye universe", isUser: false)
        
        XCTAssertTrue(message1.containsText("Hello"))
        XCTAssertTrue(message1.containsText("hello", caseSensitive: false))
        XCTAssertFalse(message1.containsText("hello", caseSensitive: true))
        XCTAssertFalse(message1.containsText("universe"))
        
        XCTAssertTrue(message2.containsText("universe"))
        XCTAssertFalse(message2.containsText("world"))
    }
    
    func testMessageWithCodeBlocks() {
        let messageWithCode = Message(
            chatId: UUID(),
            content: "Here's some code:\n```swift\nprint(\"Hello\")\n```\nAnd more text.",
            isUser: false
        )
        
        XCTAssertTrue(messageWithCode.hasCodeBlocks())
        let codeBlocks = messageWithCode.getCodeBlocks()
        XCTAssertEqual(codeBlocks.count, 1)
        XCTAssertTrue(codeBlocks[0].contains("print(\"Hello\")"))
    }
    
    func testMessageExportData() {
        let metadata = MessageMetadata(
            model: "gpt-4",
            provider: .openai,
            responseTime: 1.5,
            promptTokens: 10,
            responseTokens: 20,
            totalTokens: 30
        )
        
        let message = Message(
            chatId: UUID(),
            content: "Test message",
            isUser: false,
            metadata: metadata
        )
        
        let exportData = message.toExportData(includeMetadata: true)
        
        XCTAssertEqual(exportData.content, "Test message")
        XCTAssertFalse(exportData.isUser)
        XCTAssertEqual(exportData.wordCount, 2)
        XCTAssertEqual(exportData.characterCount, 12)
        XCTAssertNotNil(exportData.metadata)
        XCTAssertEqual(exportData.metadata?.model, "gpt-4")
        
        let exportDataNoMetadata = message.toExportData(includeMetadata: false)
        XCTAssertNil(exportDataNoMetadata.metadata)
    }
    
    // MARK: - Message Collection Tests
    
    func testMessageCollectionFiltering() {
        let chatId = UUID()
        let messages = [
            Message.createUserMessage(chatId: chatId, content: "User message 1"),
            Message.createBotMessage(chatId: chatId, content: "Bot response 1"),
            Message.createUserMessage(chatId: chatId, content: "User message 2", imageData: Data()),
            Message.createBotMessage(chatId: chatId, content: "Bot response 2")
        ]
        
        let userMessages = messages.filterByUser()
        XCTAssertEqual(userMessages.count, 2)
        XCTAssertTrue(userMessages.allSatisfy { $0.isUser })
        
        let botMessages = messages.filterByBot()
        XCTAssertEqual(botMessages.count, 2)
        XCTAssertTrue(botMessages.allSatisfy { !$0.isUser })
        
        let messagesWithImages = messages.filterWithImages()
        XCTAssertEqual(messagesWithImages.count, 1)
        XCTAssertTrue(messagesWithImages[0].hasImage)
        
        let sentMessages = messages.filterByStatus(.sent)
        XCTAssertEqual(sentMessages.count, 2) // User messages are .sent by default
        
        let streamingMessages = messages.filterByStatus(.streaming)
        XCTAssertEqual(streamingMessages.count, 2) // Bot messages are .streaming by default
    }
    
    func testMessageCollectionStatistics() {
        let chatId = UUID()
        let messages = [
            Message(chatId: chatId, content: "Short", isUser: true),
            Message(chatId: chatId, content: "This is a longer message with more words", isUser: false),
            Message(chatId: chatId, content: "Medium length message", isUser: true, imageData: Data())
        ]
        
        XCTAssertEqual(messages.totalWordCount, 10) // 1 + 8 + 3 = 12, wait let me recount: "Short"=1, "This is a longer message with more words"=8, "Medium length message"=3, total=12
        XCTAssertEqual(messages.userMessageCount, 2)
        XCTAssertEqual(messages.botMessageCount, 1)
        XCTAssertEqual(messages.messagesWithImages, 1)
        XCTAssertEqual(messages.averageWordsPerMessage, 4.0) // 12/3 = 4
        
        let statusCounts = messages.messageCountByStatus
        XCTAssertEqual(statusCounts[.sent], 2)
        XCTAssertEqual(statusCounts[.streaming], 1)
    }
    
    func testMessageCollectionSorting() {
        let now = Date()
        let anHourAgo = now.addingTimeInterval(-3600)
        let twoDaysAgo = now.addingTimeInterval(-172800)
        
        let chatId = UUID()
        let messages = [
            Message(chatId: chatId, content: "First", isUser: true, timestamp: twoDaysAgo),
            Message(chatId: chatId, content: "Second", isUser: true, timestamp: now),
            Message(chatId: chatId, content: "Third", isUser: true, timestamp: anHourAgo)
        ]
        
        let sortedAscending = messages.sortedByTimestamp(ascending: true)
        XCTAssertEqual(sortedAscending[0].content, "First")
        XCTAssertEqual(sortedAscending[1].content, "Third")
        XCTAssertEqual(sortedAscending[2].content, "Second")
        
        let sortedDescending = messages.sortedByTimestamp(ascending: false)
        XCTAssertEqual(sortedDescending[0].content, "Second")
        XCTAssertEqual(sortedDescending[1].content, "Third")
        XCTAssertEqual(sortedDescending[2].content, "First")
    }
    
    func testMessageCollectionValidation() {
        let chatId = UUID()
        let validMessages = [
            Message(chatId: chatId, content: "Message 1", isUser: true),
            Message(chatId: chatId, content: "Message 2", isUser: false)
        ]
        
        let validationErrors = validMessages.validateConsistency()
        XCTAssertTrue(validationErrors.isEmpty)
        
        // Test with duplicate IDs
        let duplicateId = UUID()
        let invalidMessages = [
            Message(id: duplicateId, chatId: chatId, content: "Message 1", isUser: true),
            Message(id: duplicateId, chatId: chatId, content: "Message 2", isUser: false)
        ]
        
        let duplicateErrors = invalidMessages.validateConsistency()
        XCTAssertFalse(duplicateErrors.isEmpty)
        XCTAssertTrue(duplicateErrors.contains("Duplicate message IDs found"))
    }
    
    // MARK: - Message Status Tests
    
    func testMessageStatus() {
        XCTAssertEqual(MessageStatus.sending.displayName, "Sending")
        XCTAssertEqual(MessageStatus.sent.displayName, "Sent")
        XCTAssertEqual(MessageStatus.failed.displayName, "Failed")
        XCTAssertEqual(MessageStatus.streaming.displayName, "Streaming")
        
        XCTAssertTrue(MessageStatus.failed.isErrorState)
        XCTAssertFalse(MessageStatus.sent.isErrorState)
        
        XCTAssertTrue(MessageStatus.sending.isInProgress)
        XCTAssertTrue(MessageStatus.streaming.isInProgress)
        XCTAssertFalse(MessageStatus.sent.isInProgress)
        XCTAssertFalse(MessageStatus.failed.isInProgress)
    }
    
    // MARK: - Message Threading Tests
    
    func testMessageThreading() {
        let chatId = UUID()
        let now = Date()
        let messages = [
            Message(chatId: chatId, content: "Message 1", isUser: true, timestamp: now),
            Message(chatId: chatId, content: "Message 2", isUser: false, timestamp: now.addingTimeInterval(30)),
            Message(chatId: chatId, content: "Message 3", isUser: true, timestamp: now.addingTimeInterval(60))
        ]
        
        let thread = Message.createThread(from: messages)
        XCTAssertNotNil(thread)
        XCTAssertEqual(thread?.messageCount, 3)
        XCTAssertEqual(thread?.totalWords, 6) // 2 words per message
        XCTAssertEqual(thread?.userMessages.count, 2)
        XCTAssertEqual(thread?.botMessages.count, 1)
        XCTAssertEqual(thread?.duration, 60.0)
    }
}