import Foundation
import Defaults

// MARK: - Chat Model

/// Core data model representing a chat conversation
/// Includes metadata, provider information, and helper methods for chat management

struct Chat: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var llmProvider: LLMProvider
    var modelName: String
    var isArchived: Bool
    var messageCount: Int
    var lastMessagePreview: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        llmProvider: LLMProvider,
        modelName: String,
        isArchived: Bool = false,
        messageCount: Int = 0,
        lastMessagePreview: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.llmProvider = llmProvider
        self.modelName = modelName
        self.isArchived = isArchived
        self.messageCount = messageCount
        self.lastMessagePreview = lastMessagePreview
    }
}

// MARK: - Chat Extensions

extension Chat {
    // MARK: - Computed Properties
    
    var displayTitle: String {
        return title.isEmpty ? "Untitled Chat" : title
    }
    
    var providerDisplayName: String {
        return llmProvider.displayName
    }
    
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var formattedUpdatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updatedAt)
    }
    
    var relativeUpdatedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
    
    var isEmpty: Bool {
        return messageCount == 0
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               createdAt <= updatedAt &&
               messageCount >= 0
    }
    
    // MARK: - Factory Methods
    
    static func createNew(
        title: String = "",
        llmProvider: LLMProvider? = nil,
        modelName: String? = nil
    ) -> Chat {
        let provider = llmProvider ?? Defaults[.defaultLLMProvider]
        let model = modelName ?? defaultModelName(for: provider)
        let chatTitle = title.isEmpty ? generateDefaultTitle(for: provider) : title
        
        return Chat(
            title: chatTitle,
            llmProvider: provider,
            modelName: model
        )
    }
    
    static func createFromTemplate(_ template: ChatTemplate) -> Chat {
        return Chat(
            title: template.title,
            llmProvider: template.llmProvider,
            modelName: template.modelName
        )
    }
    
    // MARK: - Update Methods
    
    mutating func updateTitle(_ newTitle: String) {
        guard !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = Date()
    }
    
    mutating func updateProvider(_ newProvider: LLMProvider, modelName newModelName: String? = nil) {
        self.llmProvider = newProvider
        self.modelName = newModelName ?? Self.defaultModelName(for: newProvider)
        self.updatedAt = Date()
    }
    
    mutating func updateModel(_ newModelName: String) {
        guard !newModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.modelName = newModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = Date()
    }
    
    mutating func markUpdated() {
        self.updatedAt = Date()
    }
    
    mutating func incrementMessageCount() {
        self.messageCount += 1
        self.updatedAt = Date()
    }
    
    mutating func decrementMessageCount() {
        if self.messageCount > 0 {
            self.messageCount -= 1
            self.updatedAt = Date()
        }
    }
    
    mutating func updateMessageCount(_ count: Int) {
        self.messageCount = max(0, count)
        self.updatedAt = Date()
    }
    
    mutating func updateLastMessagePreview(_ preview: String?) {
        self.lastMessagePreview = preview
        self.updatedAt = Date()
    }
    
    mutating func archive() {
        self.isArchived = true
        self.updatedAt = Date()
    }
    
    mutating func unarchive() {
        self.isArchived = false
        self.updatedAt = Date()
    }
    
    // MARK: - Helper Methods
    
    private static func defaultModelName(for provider: LLMProvider) -> String {
        switch provider {
        case .openai:
            return Defaults[.openaiModel]
        case .anthropic:
            return Defaults[.anthropicModel]
        case .google:
            return Defaults[.googleModel]
        case .local:
            return Defaults[.localModelPath].isEmpty ? "local-model" : Defaults[.localModelPath]
        }
    }
    
    private static func generateDefaultTitle(for provider: LLMProvider) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let timestamp = formatter.string(from: Date())
        return "\(provider.displayName) Chat - \(timestamp)"
    }
}

// MARK: - Chat Template

struct ChatTemplate: Identifiable, Codable {
    let id: UUID
    let title: String
    let llmProvider: LLMProvider
    let modelName: String
    let description: String?
    let isBuiltIn: Bool
    
    init(
        id: UUID = UUID(),
        title: String,
        llmProvider: LLMProvider,
        modelName: String,
        description: String? = nil,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.title = title
        self.llmProvider = llmProvider
        self.modelName = modelName
        self.description = description
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Built-in Templates

extension ChatTemplate {
    static let builtInTemplates: [ChatTemplate] = [
        ChatTemplate(
            title: "General Chat",
            llmProvider: .openai,
            modelName: "gpt-4",
            description: "General purpose conversation with GPT-4",
            isBuiltIn: true
        ),
        ChatTemplate(
            title: "Creative Writing",
            llmProvider: .anthropic,
            modelName: "claude-3-sonnet-20240229",
            description: "Creative writing and storytelling with Claude",
            isBuiltIn: true
        ),
        ChatTemplate(
            title: "Code Assistant",
            llmProvider: .openai,
            modelName: "gpt-4",
            description: "Programming and code assistance",
            isBuiltIn: true
        ),
        ChatTemplate(
            title: "Research Helper",
            llmProvider: .google,
            modelName: "gemini-pro",
            description: "Research and analysis with Gemini",
            isBuiltIn: true
        ),
        ChatTemplate(
            title: "Local Model",
            llmProvider: .local,
            modelName: "local-model",
            description: "Chat with local language model",
            isBuiltIn: true
        )
    ]
}

// MARK: - Chat Sorting and Filtering

extension Chat {
    enum SortOption: String, CaseIterable {
        case updatedDate = "updatedDate"
        case createdDate = "createdDate"
        case title = "title"
        case provider = "provider"
        case messageCount = "messageCount"
        
        var displayName: String {
            switch self {
            case .updatedDate: return "Last Updated"
            case .createdDate: return "Date Created"
            case .title: return "Title"
            case .provider: return "Provider"
            case .messageCount: return "Message Count"
            }
        }
    }
    
    enum FilterOption: String, CaseIterable {
        case all = "all"
        case openai = "openai"
        case anthropic = "anthropic"
        case google = "google"
        case local = "local"
        case archived = "archived"
        case active = "active"
        
        var displayName: String {
            switch self {
            case .all: return "All Chats"
            case .openai: return "OpenAI"
            case .anthropic: return "Anthropic"
            case .google: return "Google AI"
            case .local: return "Local"
            case .archived: return "Archived"
            case .active: return "Active"
            }
        }
    }
    
    static func sort(_ chats: [Chat], by option: SortOption, ascending: Bool = false) -> [Chat] {
        switch option {
        case .updatedDate:
            return chats.sorted { ascending ? $0.updatedAt < $1.updatedAt : $0.updatedAt > $1.updatedAt }
        case .createdDate:
            return chats.sorted { ascending ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }
        case .title:
            return chats.sorted { ascending ? $0.title < $1.title : $0.title > $1.title }
        case .provider:
            return chats.sorted { ascending ? $0.llmProvider.rawValue < $1.llmProvider.rawValue : $0.llmProvider.rawValue > $1.llmProvider.rawValue }
        case .messageCount:
            return chats.sorted { ascending ? $0.messageCount < $1.messageCount : $0.messageCount > $1.messageCount }
        }
    }
    
    static func filter(_ chats: [Chat], by option: FilterOption) -> [Chat] {
        switch option {
        case .all:
            return chats
        case .openai:
            return chats.filter { $0.llmProvider == .openai }
        case .anthropic:
            return chats.filter { $0.llmProvider == .anthropic }
        case .google:
            return chats.filter { $0.llmProvider == .google }
        case .local:
            return chats.filter { $0.llmProvider == .local }
        case .archived:
            return chats.filter { $0.isArchived }
        case .active:
            return chats.filter { !$0.isArchived }
        }
    }
    
    static func search(_ chats: [Chat], query: String) -> [Chat] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return chats
        }
        
        let searchQuery = query.lowercased()
        return chats.filter { chat in
            chat.title.lowercased().contains(searchQuery) ||
            chat.modelName.lowercased().contains(searchQuery) ||
            chat.llmProvider.displayName.lowercased().contains(searchQuery) ||
            (chat.lastMessagePreview?.lowercased().contains(searchQuery) ?? false)
        }
    }
}

// MARK: - Chat Export

extension Chat {
    struct ExportData: Codable {
        let id: String
        let title: String
        let createdAt: String
        let updatedAt: String
        let llmProvider: String
        let modelName: String
        let messageCount: Int
        let isArchived: Bool
    }
    
    func toExportData() -> ExportData {
        let formatter = ISO8601DateFormatter()
        return ExportData(
            id: id.uuidString,
            title: title,
            createdAt: formatter.string(from: createdAt),
            updatedAt: formatter.string(from: updatedAt),
            llmProvider: llmProvider.rawValue,
            modelName: modelName,
            messageCount: messageCount,
            isArchived: isArchived
        )
    }
    
    static func fromExportData(_ data: ExportData) -> Chat? {
        guard let id = UUID(uuidString: data.id),
              let provider = LLMProvider(rawValue: data.llmProvider) else {
            return nil
        }
        
        let formatter = ISO8601DateFormatter()
        let createdAt = formatter.date(from: data.createdAt) ?? Date()
        let updatedAt = formatter.date(from: data.updatedAt) ?? Date()
        
        return Chat(
            id: id,
            title: data.title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            llmProvider: provider,
            modelName: data.modelName,
            isArchived: data.isArchived,
            messageCount: data.messageCount
        )
    }
}

// MARK: - Chat Statistics

extension Chat {
    struct Statistics {
        let totalChats: Int
        let chatsByProvider: [LLMProvider: Int]
        let averageMessagesPerChat: Double
        let oldestChat: Date?
        let newestChat: Date?
        let archivedCount: Int
        let activeCount: Int
    }
    
    static func generateStatistics(from chats: [Chat]) -> Statistics {
        let totalChats = chats.count
        let archivedCount = chats.filter { $0.isArchived }.count
        let activeCount = totalChats - archivedCount
        
        var chatsByProvider: [LLMProvider: Int] = [:]
        for provider in LLMProvider.allCases {
            chatsByProvider[provider] = chats.filter { $0.llmProvider == provider }.count
        }
        
        let totalMessages = chats.reduce(0) { $0 + $1.messageCount }
        let averageMessages = totalChats > 0 ? Double(totalMessages) / Double(totalChats) : 0.0
        
        let sortedByDate = chats.sorted { $0.createdAt < $1.createdAt }
        let oldestChat = sortedByDate.first?.createdAt
        let newestChat = sortedByDate.last?.createdAt
        
        return Statistics(
            totalChats: totalChats,
            chatsByProvider: chatsByProvider,
            averageMessagesPerChat: averageMessages,
            oldestChat: oldestChat,
            newestChat: newestChat,
            archivedCount: archivedCount,
            activeCount: activeCount
        )
    }
}