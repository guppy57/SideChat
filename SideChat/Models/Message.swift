import Foundation

// MARK: - Message Model

/// Core data model representing individual chat messages
/// Supports text content, images, metadata, and status tracking

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let chatId: UUID
    var content: String
    let isUser: Bool
    let timestamp: Date
    var imageData: Data?
    var metadata: MessageMetadata?
    var status: MessageStatus
    var tokens: Int?
    var editedAt: Date?
    
    init(
        id: UUID = UUID(),
        chatId: UUID,
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        imageData: Data? = nil,
        metadata: MessageMetadata? = nil,
        status: MessageStatus = .sent,
        tokens: Int? = nil,
        editedAt: Date? = nil
    ) {
        self.id = id
        self.chatId = chatId
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.imageData = imageData
        self.metadata = metadata
        self.status = status
        self.tokens = tokens
        self.editedAt = editedAt
    }
}

// MARK: - Message Status

enum MessageStatus: String, Codable, CaseIterable {
    case sending = "sending"
    case sent = "sent"
    case failed = "failed"
    case streaming = "streaming"
    case edited = "edited"
    case deleted = "deleted"
    
    var displayName: String {
        switch self {
        case .sending: return "Sending"
        case .sent: return "Sent"
        case .failed: return "Failed"
        case .streaming: return "Streaming"
        case .edited: return "Edited"
        case .deleted: return "Deleted"
        }
    }
    
    var isErrorState: Bool {
        return self == .failed
    }
    
    var isInProgress: Bool {
        return self == .sending || self == .streaming
    }
}

// MARK: - Message Metadata

struct MessageMetadata: Codable, Hashable {
    let model: String?
    let provider: LLMProvider?
    let providerConfigId: UUID? // Which provider configuration was used
    let responseTime: TimeInterval?
    let promptTokens: Int?
    let responseTokens: Int?
    let totalTokens: Int?
    let temperature: Double?
    let maxTokens: Int?
    let finishReason: String?
    let error: MessageError?
    
    init(
        model: String? = nil,
        provider: LLMProvider? = nil,
        providerConfigId: UUID? = nil,
        responseTime: TimeInterval? = nil,
        promptTokens: Int? = nil,
        responseTokens: Int? = nil,
        totalTokens: Int? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        finishReason: String? = nil,
        error: MessageError? = nil
    ) {
        self.model = model
        self.provider = provider
        self.providerConfigId = providerConfigId
        self.responseTime = responseTime
        self.promptTokens = promptTokens
        self.responseTokens = responseTokens
        self.totalTokens = totalTokens
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.finishReason = finishReason
        self.error = error
    }
}

// MARK: - Message Error

struct MessageError: Codable, Hashable {
    let code: String
    let message: String
    let details: String?
    let timestamp: Date
    
    init(code: String, message: String, details: String? = nil, timestamp: Date = Date()) {
        self.code = code
        self.message = message
        self.details = details
        self.timestamp = timestamp
    }
}

// MARK: - Message Extensions

extension Message {
    // MARK: - Computed Properties
    
    var isFromBot: Bool {
        return !isUser
    }
    
    var hasImage: Bool {
        return imageData != nil
    }
    
    var isEmpty: Bool {
        return content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasImage
    }
    
    var isEdited: Bool {
        return editedAt != nil
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var detailedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var wordCount: Int {
        return content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    var characterCount: Int {
        return content.count
    }
    
    var preview: String {
        let maxLength = 100
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.count <= maxLength {
            return trimmed
        }
        
        let truncated = String(trimmed.prefix(maxLength))
        return truncated + "..."
    }
    
    var shortPreview: String {
        let maxLength = 50
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.count <= maxLength {
            return trimmed
        }
        
        let truncated = String(trimmed.prefix(maxLength))
        return truncated + "..."
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasImage
    }
    
    // MARK: - Factory Methods
    
    static func createUserMessage(
        chatId: UUID,
        content: String,
        imageData: Data? = nil
    ) -> Message {
        return Message(
            chatId: chatId,
            content: content,
            isUser: true,
            imageData: imageData,
            status: .sent
        )
    }
    
    static func createBotMessage(
        chatId: UUID,
        content: String = "",
        metadata: MessageMetadata? = nil,
        status: MessageStatus = .streaming
    ) -> Message {
        return Message(
            chatId: chatId,
            content: content,
            isUser: false,
            metadata: metadata,
            status: status
        )
    }
    
    static func createSystemMessage(
        chatId: UUID,
        content: String
    ) -> Message {
        return Message(
            chatId: chatId,
            content: content,
            isUser: false,
            status: .sent
        )
    }
    
    // MARK: - Update Methods
    
    mutating func updateContent(_ newContent: String) {
        self.content = newContent
        self.editedAt = Date()
        self.status = .edited
    }
    
    mutating func appendContent(_ additionalContent: String) {
        self.content += additionalContent
    }
    
    mutating func setStatus(_ newStatus: MessageStatus) {
        self.status = newStatus
    }
    
    mutating func markAsSent() {
        self.status = .sent
    }
    
    mutating func markAsFailed(error: MessageError? = nil) {
        self.status = .failed
        if let error = error {
            if var existingMetadata = self.metadata {
                existingMetadata = MessageMetadata(
                    model: existingMetadata.model,
                    provider: existingMetadata.provider,
                    providerConfigId: existingMetadata.providerConfigId,
                    responseTime: existingMetadata.responseTime,
                    promptTokens: existingMetadata.promptTokens,
                    responseTokens: existingMetadata.responseTokens,
                    totalTokens: existingMetadata.totalTokens,
                    temperature: existingMetadata.temperature,
                    maxTokens: existingMetadata.maxTokens,
                    finishReason: existingMetadata.finishReason,
                    error: error
                )
                self.metadata = existingMetadata
            } else {
                self.metadata = MessageMetadata(error: error)
            }
        }
    }
    
    mutating func updateMetadata(_ newMetadata: MessageMetadata) {
        self.metadata = newMetadata
    }
    
    mutating func setTokenCount(_ tokens: Int) {
        self.tokens = tokens
    }
    
    mutating func addImage(_ data: Data) {
        self.imageData = data
    }
    
    mutating func removeImage() {
        self.imageData = nil
    }
    
    // MARK: - Content Processing
    
    func containsText(_ searchText: String, caseSensitive: Bool = false) -> Bool {
        if caseSensitive {
            return content.contains(searchText)
        } else {
            return content.lowercased().contains(searchText.lowercased())
        }
    }
    
    func getMarkdownContent() -> String {
        return content
    }
    
    func getPlainTextContent() -> String {
        // Simple markdown removal - in a real app you'd use a proper markdown parser
        return content
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "#", with: "")
    }
    
    func hasCodeBlocks() -> Bool {
        return content.contains("```")
    }
    
    func getCodeBlocks() -> [String] {
        let pattern = "```[\\s\\S]*?```"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = content as NSString
        let results = regex?.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
        
        return results?.compactMap { result in
            nsString.substring(with: result.range)
        } ?? []
    }
    
    // MARK: - Export
    
    func toExportData(includeMetadata: Bool = true) -> MessageExportData {
        return MessageExportData(
            id: id.uuidString,
            chatId: chatId.uuidString,
            content: content,
            isUser: isUser,
            timestamp: ISO8601DateFormatter().string(from: timestamp),
            hasImage: hasImage,
            status: status.rawValue,
            wordCount: wordCount,
            characterCount: characterCount,
            metadata: includeMetadata ? metadata : nil,
            editedAt: editedAt != nil ? ISO8601DateFormatter().string(from: editedAt!) : nil
        )
    }
}

// MARK: - Message Export Data

struct MessageExportData: Codable {
    let id: String
    let chatId: String
    let content: String
    let isUser: Bool
    let timestamp: String
    let hasImage: Bool
    let status: String
    let wordCount: Int
    let characterCount: Int
    let metadata: MessageMetadata?
    let editedAt: String?
}

// MARK: - Message Collection Extensions

extension Array where Element == Message {
    // MARK: - Filtering
    
    func filterByUser() -> [Message] {
        return filter { $0.isUser }
    }
    
    func filterByBot() -> [Message] {
        return filter { !$0.isUser }
    }
    
    func filterByStatus(_ status: MessageStatus) -> [Message] {
        return filter { $0.status == status }
    }
    
    func filterWithImages() -> [Message] {
        return filter { $0.hasImage }
    }
    
    func filterByDateRange(from startDate: Date, to endDate: Date) -> [Message] {
        return filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }
    
    func search(_ query: String, caseSensitive: Bool = false) -> [Message] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return self
        }
        
        return filter { message in
            message.containsText(query, caseSensitive: caseSensitive)
        }
    }
    
    // MARK: - Sorting
    
    func sortedByTimestamp(ascending: Bool = true) -> [Message] {
        return sorted { ascending ? $0.timestamp < $1.timestamp : $0.timestamp > $1.timestamp }
    }
    
    func sortedByWordCount(ascending: Bool = true) -> [Message] {
        return sorted { ascending ? $0.wordCount < $1.wordCount : $0.wordCount > $1.wordCount }
    }
    
    // MARK: - Statistics
    
    var totalWordCount: Int {
        return reduce(0) { $0 + $1.wordCount }
    }
    
    var totalCharacterCount: Int {
        return reduce(0) { $0 + $1.characterCount }
    }
    
    var userMessageCount: Int {
        return filterByUser().count
    }
    
    var botMessageCount: Int {
        return filterByBot().count
    }
    
    var messageCountByStatus: [MessageStatus: Int] {
        var counts: [MessageStatus: Int] = [:]
        for status in MessageStatus.allCases {
            counts[status] = filterByStatus(status).count
        }
        return counts
    }
    
    var averageWordsPerMessage: Double {
        guard !isEmpty else { return 0.0 }
        return Double(totalWordCount) / Double(count)
    }
    
    var messagesWithImages: Int {
        return filterWithImages().count
    }
    
    var dateRange: (oldest: Date?, newest: Date?) {
        guard !isEmpty else { return (nil, nil) }
        let sorted = sortedByTimestamp()
        return (sorted.first?.timestamp, sorted.last?.timestamp)
    }
    
    // MARK: - Grouping
    
    func groupedByDate() -> [Date: [Message]] {
        let calendar = Calendar.current
        var grouped: [Date: [Message]] = [:]
        
        for message in self {
            let dateKey = calendar.startOfDay(for: message.timestamp)
            if grouped[dateKey] == nil {
                grouped[dateKey] = []
            }
            grouped[dateKey]?.append(message)
        }
        
        return grouped
    }
    
    func groupedByStatus() -> [MessageStatus: [Message]] {
        var grouped: [MessageStatus: [Message]] = [:]
        
        for message in self {
            if grouped[message.status] == nil {
                grouped[message.status] = []
            }
            grouped[message.status]?.append(message)
        }
        
        return grouped
    }
    
    // MARK: - Validation
    
    func validateConsistency() -> [String] {
        var errors: [String] = []
        
        // Check for duplicate IDs
        let ids = map { $0.id }
        let uniqueIds = Set(ids)
        if ids.count != uniqueIds.count {
            errors.append("Duplicate message IDs found")
        }
        
        // Check timestamp ordering
        let sorted = sortedByTimestamp()
        if self != sorted {
            errors.append("Messages are not in chronological order")
        }
        
        // Check for empty content without images
        let emptyMessages = filter { $0.isEmpty }
        if !emptyMessages.isEmpty {
            errors.append("\(emptyMessages.count) empty messages found")
        }
        
        return errors
    }
}

// MARK: - Message Threading

extension Message {
    // MARK: - Thread Support
    
    var threadId: String? {
        return metadata?.provider?.rawValue
    }
    
    func isPartOfThread(with other: Message) -> Bool {
        return chatId == other.chatId && 
               abs(timestamp.timeIntervalSince(other.timestamp)) < 300 // 5 minutes
    }
    
    static func createThread(from messages: [Message]) -> MessageThread? {
        guard !messages.isEmpty else { return nil }
        
        let sortedMessages = messages.sortedByTimestamp()
        let startTime = sortedMessages.first!.timestamp
        let endTime = sortedMessages.last!.timestamp
        let duration = endTime.timeIntervalSince(startTime)
        
        return MessageThread(
            id: UUID(),
            messages: sortedMessages,
            startTime: startTime,
            endTime: endTime,
            duration: duration
        )
    }
}

// MARK: - Message Thread

struct MessageThread: Identifiable, Codable {
    let id: UUID
    let messages: [Message]
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    
    var messageCount: Int {
        return messages.count
    }
    
    var totalWords: Int {
        return messages.totalWordCount
    }
    
    var userMessages: [Message] {
        return messages.filterByUser()
    }
    
    var botMessages: [Message] {
        return messages.filterByBot()
    }
}