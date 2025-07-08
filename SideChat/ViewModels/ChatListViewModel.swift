import Foundation
import SwiftUI
import Combine
import Defaults

// MARK: - Chat List View Model

/// View model for managing the chat list display and operations
/// Handles loading, searching, filtering, and chat management
@MainActor
class ChatListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var chats: [Chat] = []
    @Published private(set) var filteredChats: [Chat] = []
    @Published var searchText = "" {
        didSet {
            filterChats()
        }
    }
    @Published var selectedChatId: UUID?
    @Published private(set) var isLoading = false
    @Published var error: Error?
    @Published var filterOption: Chat.FilterOption = .active {
        didSet {
            filterChats()
        }
    }
    @Published var sortOption: Chat.SortOption = .updatedDate {
        didSet {
            filterChats()
        }
    }
    
    // MARK: - Properties
    
    private let databaseManager: DatabaseManager
    private var cancellables = Set<AnyCancellable>()
    
    // Settings
    @Default(.defaultLLMProvider) private var defaultProvider
    
    // MARK: - Initialization
    
    init() {
        self.databaseManager = DatabaseManager.shared
        
        // Setup search debouncing
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterChats()
            }
            .store(in: &cancellables)
        
        // Load chats on init with error handling
        Task {
            do {
                // Small delay to ensure database is initialized
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await loadChats()
            } catch {
                print("Failed to load chats on init: \(error)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all chats from database
    func loadChats() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            chats = try await databaseManager.loadAllChats()
            filterChats()
        } catch {
            self.error = error
            print("Failed to load chats: \(error)")
        }
    }
    
    /// Refresh chat list
    func refresh() async {
        await loadChats()
    }
    
    /// Create a new chat
    func createNewChat() async -> Chat? {
        let newChat = Chat.createNew(
            title: "New Chat",
            llmProvider: defaultProvider
        )
        
        do {
            try await databaseManager.saveChat(newChat)
            await loadChats()
            selectedChatId = newChat.id
            return newChat
        } catch {
            self.error = error
            print("Failed to create new chat: \(error)")
            return nil
        }
    }
    
    /// Delete a chat
    func deleteChat(_ chat: Chat) async {
        do {
            try await databaseManager.deleteChat(id: chat.id)
            
            // If deleting the selected chat, clear selection
            if selectedChatId == chat.id {
                selectedChatId = nil
            }
            
            await loadChats()
        } catch {
            self.error = error
            print("Failed to delete chat: \(error)")
        }
    }
    
    /// Archive/unarchive a chat
    func toggleArchive(_ chat: Chat) async {
        var updatedChat = chat
        if chat.isArchived {
            updatedChat.unarchive()
        } else {
            updatedChat.archive()
        }
        
        do {
            try await databaseManager.saveChat(updatedChat)
            await loadChats()
        } catch {
            self.error = error
            print("Failed to archive/unarchive chat: \(error)")
        }
    }
    
    /// Rename a chat
    func renameChat(_ chat: Chat, newTitle: String) async {
        guard !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        var updatedChat = chat
        updatedChat.updateTitle(newTitle)
        
        do {
            try await databaseManager.saveChat(updatedChat)
            await loadChats()
        } catch {
            self.error = error
            print("Failed to rename chat: \(error)")
        }
    }
    
    /// Select a chat
    func selectChat(_ chat: Chat) {
        selectedChatId = chat.id
    }
    
    // MARK: - Private Methods
    
    /// Filter and sort chats based on current settings
    private func filterChats() {
        var filtered = chats
        
        // Apply filter option
        filtered = Chat.filter(filtered, by: filterOption)
        
        // Apply search if text is not empty
        if !searchText.isEmpty {
            filtered = Chat.search(filtered, query: searchText)
        }
        
        // Apply sorting
        filtered = Chat.sort(filtered, by: sortOption)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            filteredChats = filtered
        }
    }
    
    // MARK: - Computed Properties
    
    /// Check if there are any chats
    var hasChats: Bool {
        !chats.isEmpty
    }
    
    /// Check if there are any filtered chats
    var hasFilteredChats: Bool {
        !filteredChats.isEmpty
    }
    
    /// Get the currently selected chat
    var selectedChat: Chat? {
        guard let selectedChatId = selectedChatId else { return nil }
        return chats.first { $0.id == selectedChatId }
    }
    
    /// Get empty state message based on current filter
    var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No chats found matching \"\(searchText)\""
        }
        
        switch filterOption {
        case .all, .active:
            return "No chats yet. Create one to get started!"
        case .archived:
            return "No archived chats"
        case .openai:
            return "No OpenAI chats"
        case .anthropic:
            return "No Anthropic chats"  
        case .google:
            return "No Google AI chats"
        case .local:
            return "No local model chats"
        }
    }
    
    /// Get stats for the current chat list
    func getStats() -> Chat.Statistics {
        Chat.generateStatistics(from: chats)
    }
}

// MARK: - Chat List Item Model

/// Represents a chat item in the list with additional display properties
struct ChatListItem: Identifiable {
    let chat: Chat
    let isSelected: Bool
    let lastMessageTime: String
    
    var id: UUID { chat.id }
    
    var providerIcon: String {
        switch chat.llmProvider {
        case .openai:
            return "brain"
        case .anthropic:
            return "ant"
        case .google:
            return "magnifyingglass"
        case .local:
            return "desktopcomputer"
        }
    }
    
    var providerColor: Color {
        switch chat.llmProvider {
        case .openai:
            return .green
        case .anthropic:
            return .orange
        case .google:
            return .blue
        case .local:
            return .purple
        }
    }
}