import SwiftUI
import AppKit
import Defaults
import UniformTypeIdentifiers

// MARK: - Sidebar View

/// Main sidebar view that contains all chat interface elements
struct SidebarView: View {
    
    // MARK: - Properties
    
    @Default(.sidebarTransparency) private var transparency
    @Default(.colorTheme) private var colorTheme
    @Default(.enableImageUploads) private var enableImageUploads
    @State private var messageText = ""
    @StateObject private var chatViewModel: ChatViewModel
    @State private var selectedImages: [Data] = []
    @State private var showImagePicker = false
    @State private var isDragTargeted = false
    @State private var selectedChatId: UUID?
    @State private var currentChat: Chat?
    @State private var isRenamingChat = false
    @State private var renameChatTitle = ""
    @StateObject private var chatListViewModel = ChatListViewModel()
    @State private var showChatList = false
    @FocusState private var isMessageFieldFocused: Bool
    @Environment(\.openSettings) private var openSettings
    
    // MARK: - Initialization
    
    init(chatId: UUID? = nil) {
        let initialChatId = chatId ?? UUID()
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(chatId: initialChatId))
        _selectedChatId = State(initialValue: chatId)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area with conditional rendering for performance
            if showChatList {
                // Inline chat list view
                InlineChatListView(
                    chatListViewModel: chatListViewModel,
                    selectedChatId: $selectedChatId,
                    onChatSelected: { chatId in
                        // Immediate visual feedback and animation start
                        selectedChatId = chatId
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showChatList = false
                        }
                        
                        // Load chat data in background while animation plays
                        Task {
                            await switchToChat(chatId)
                            // Delay focus to ensure view transition is complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                isMessageFieldFocused = true
                            }
                        }
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showChatList = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Chat view (only rendered when not showing chat list)
                ChatView(viewModel: chatViewModel)
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }
            
            // Combined input and toolbar area
            inputToolbar
            
            // Chat header below the input toolbar
            if let chat = currentChat {
                HStack(spacing: 8) {
                    // Chat icon
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 14))
                        .foregroundColor(accentColor)
                    
                    // Chat title
                    if isRenamingChat {
                        TextField("Chat Title", text: $renameChatTitle)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 13, weight: .medium))
                            .onSubmit {
                                Task {
                                    await renameCurrentChat(renameChatTitle)
                                    isRenamingChat = false
                                }
                            }
                            .onAppear {
                                renameChatTitle = chat.title
                            }
                    } else {
                        Text(chat.displayTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .contextMenu {
                                Button(action: {
                                    renameChatTitle = chat.title
                                    isRenamingChat = true
                                }) {
                                    Label("Rename Chat", systemImage: "pencil")
                                }
                            }
                    }
                    
                    Spacer()
                    
                    // Provider selector
                    if !chatViewModel.availableProviders.isEmpty {
                        Menu {
                            ForEach(chatViewModel.availableProviders) { config in
                                Button(action: {
                                    chatViewModel.switchToProvider(config.id)
                                }) {
                                    HStack {
                                        Image(systemName: providerIcon(for: config.provider))
                                        Text("\(config.friendlyName) (\(config.selectedModel))")
                                        if config.id == chatViewModel.currentProviderId {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if let currentConfig = chatViewModel.currentProviderConfig {
                                    Image(systemName: providerIcon(for: currentConfig.provider))
                                        .font(.system(size: 11))
                                    Text(currentConfig.friendlyName)
                                        .font(.system(size: 11, weight: .medium))
                                } else {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 11))
                                    Text("No Provider")
                                        .font(.system(size: 11, weight: .medium))
                                }
                            }
                            .foregroundColor(providerColor(for: chatViewModel.currentProviderConfig?.provider ?? .openai))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(providerColor(for: chatViewModel.currentProviderConfig?.provider ?? .openai).opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(providerColor(for: chatViewModel.currentProviderConfig?.provider ?? .openai).opacity(0.3), lineWidth: 0.5)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.visible)
                    } else {
                        // No configured providers
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 11))
                            Text("No Providers")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        
                        BlurredBackgroundView(
                            material: .sidebar,
                            opacity: 1.0
                        )
                        .cornerRadius(16)
                    }
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .allowsHitTesting(false)
        )
        .onDrop(of: [.image, .fileURL], isTargeted: $isDragTargeted, perform: handleDrop)
        .overlay(
            isDragTargeted && enableImageUploads ? ZStack {
                Color.black.opacity(0.7)
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 60))
                    Text("Drop image here")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
            }
            .allowsHitTesting(false) : nil
        )
        .background {
            ImagePickerView(selectedImages: $selectedImages, isPresented: $showImagePicker)
        }
        .onReceive(NotificationCenter.default.publisher(for: .paste)) { _ in
            handlePaste()
        }
        .onChange(of: selectedChatId) { _, newChatId in
            if let chatId = newChatId {
                Task {
                    await switchToChat(chatId)
                }
            }
        }
        .onChange(of: currentChat) { _, _ in
            isRenamingChat = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isRenamingChat = false
        }
        .task {
            // Load chats for the menu
            await chatListViewModel.loadChats()
            
            // Set up initial chat
            do {
                let chats = try await DatabaseManager.shared.loadAllChats()
                if let firstChat = chats.first {
                    selectedChatId = firstChat.id
                    currentChat = firstChat
                    chatViewModel.loadMessages(for: firstChat.id)
                } else {
                    await createInitialChat()
                }
            } catch {
                print("Failed to load initial chats: \(error)")
                await createInitialChat()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var accentColor: Color {
        switch colorTheme {
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .orange: return .orange
        case .gray: return .gray
        }
    }
    
    
    private var inputToolbar: some View {
        VStack(spacing: 0) {
            if !selectedImages.isEmpty {
                InlineImagesPreview(images: $selectedImages)
            }
            
            HStack(spacing: 8) {
                Button(action: createNewChat) {
                    Image(systemName: "plus.bubble")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .help("New Chat")
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showChatList.toggle()
                    }
                }) {
                    Image(systemName: showChatList ? "xmark" : "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .help(showChatList ? "Close Chat List" : "Chat History")
                
                if enableImageUploads {
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "photo")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.primary.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Attach Image")
                }
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)
                
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .lineLimit(1...5)
                    .focused($isMessageFieldFocused)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: togglePin) {
                    Image(systemName: SidebarWindowController.shared.isSidebarPinned ? "pin.fill" : "pin")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .help(SidebarWindowController.shared.isSidebarPinned ? "Unpin Sidebar" : "Pin Sidebar")
                
                Button(action: { openSettings() }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings")
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(accentColor)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Send Message")
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImages.isEmpty || chatViewModel.isTyping)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                
                BlurredBackgroundView(
                    material: .sidebar,
                    opacity: 1.0
                )
                .cornerRadius(20)
            }
            .shadow(
                color: Color.black.opacity(0.25),
                radius: 10,
                x: 0,
                y: 3
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(16)
    }
    
    // MARK: - Actions
    
    private func createNewChat() {
        Task {
            let newChat = Chat.createNew(
                title: "New Chat",
                llmProvider: Defaults[.defaultLLMProvider]
            )
            
            do {
                try await DatabaseManager.shared.saveChat(newChat)
                currentChat = newChat
                selectedChatId = newChat.id
                chatViewModel.loadMessages(for: newChat.id)
                
                // Refresh the chat list for the menu
                await chatListViewModel.loadChats()
            } catch {
                print("Failed to create new chat: \(error)")
            }
        }
    }
    
    
    private func togglePin() {
        let currentState = SidebarWindowController.shared.isSidebarPinned
        SidebarWindowController.shared.setSidebarPinned(!currentState)
    }
    
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMessage.isEmpty || !selectedImages.isEmpty {
            chatViewModel.sendMessage(content: trimmedMessage, images: selectedImages)
            messageText = ""
            selectedImages.removeAll()
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard enableImageUploads else { return false }
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                    DispatchQueue.main.async {
                        if let data = data,
                           data.count <= 20 * 1024 * 1024,
                           NSImage(data: data) != nil {
                            selectedImages.append(data)
                        }
                        isDragTargeted = false
                    }
                }
                return true
            }
        }
        
        return false
    }
    
    private func handlePaste() {
        guard enableImageUploads else { return }
        
        if let imageData = ClipboardImageHandler.getImageFromClipboard() {
            selectedImages.append(imageData)
        }
    }
    
    // MARK: - Helper Functions
    
    private func providerIcon(for provider: LLMProvider) -> String {
        switch provider {
        case .openai:
            return "brain"
        case .anthropic:
            return "ant.circle"
        case .google:
            return "sparkle"
        case .local:
            return "desktopcomputer"
        }
    }
    
    private func providerColor(for provider: LLMProvider) -> Color {
        switch provider {
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
    
    // MARK: - Chat Management
    
    private func switchToChat(_ chatId: UUID) async {
        do {
            if let chat = try await DatabaseManager.shared.loadChat(id: chatId) {
                currentChat = chat
                chatViewModel.loadMessages(for: chatId)
                selectedChatId = chatId
            }
        } catch {
            print("Failed to switch chat: \(error)")
        }
    }
    
    private func renameCurrentChat(_ newTitle: String) async {
        guard var chat = currentChat else { return }
        
        chat.updateTitle(newTitle)
        
        do {
            try await DatabaseManager.shared.saveChat(chat)
            currentChat = chat
        } catch {
            print("Failed to rename chat: \(error)")
        }
    }
    
    private func createInitialChat() async {
        let chatToSave = Chat(
            id: chatViewModel.chatId,
            title: "New Chat",
            createdAt: Date(),
            updatedAt: Date(),
            llmProvider: Defaults[.defaultLLMProvider],
            modelName: getDefaultModelName(for: Defaults[.defaultLLMProvider]),
            isArchived: false,
            messageCount: 0,
            lastMessagePreview: nil
        )
        
        do {
            try await DatabaseManager.shared.saveChat(chatToSave)
            currentChat = chatToSave
            selectedChatId = chatToSave.id
        } catch {
            print("Failed to create initial chat: \(error)")
        }
    }
    
    private func getDefaultModelName(for provider: LLMProvider) -> String {
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
}

// MARK: - Notification Extension

extension Notification.Name {
    static let paste = Notification.Name("NSPasteboardDidChangeNotification")
}

// MARK: - Inline Chat List View

/// A streamlined inline chat list view that appears in place of the chat area
struct InlineChatListView: View {
    @ObservedObject var chatListViewModel: ChatListViewModel
    @Binding var selectedChatId: UUID?
    let onChatSelected: (UUID) -> Void
    let onClose: () -> Void
    
    @FocusState private var isSearchFocused: Bool
    @Default(.colorTheme) private var colorTheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and close button
            headerView
            
            // Chat list content
            if chatListViewModel.isLoading {
                loadingView
            } else if chatListViewModel.hasFilteredChats {
                chatListView
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                
                BlurredBackgroundView(
                    material: .sidebar,
                    opacity: 1.0
                )
                .cornerRadius(20)
            }
            .shadow(
                color: Color.black.opacity(0.25),
                radius: 10,
                x: 0,
                y: 3
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(16)
        .onAppear {
            chatListViewModel.selectedChatId = selectedChatId
            isSearchFocused = true
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Chat History")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField("Search chats...", text: $chatListViewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .focused($isSearchFocused)
                
                if !chatListViewModel.searchText.isEmpty {
                    Button(action: { chatListViewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )
            
            // Filter options (simplified)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([Chat.FilterOption.active, .openai, .anthropic, .google, .local], id: \.self) { option in
                        FilterChip(
                            title: option.displayName,
                            isSelected: chatListViewModel.filterOption == option,
                            action: { chatListViewModel.filterOption = option }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
    }
    
    private var chatListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(chatListViewModel.filteredChats) { chat in
                    InlineChatListItemView(
                        chat: chat,
                        isSelected: selectedChatId == chat.id,
                        onSelect: {
                            onChatSelected(chat.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(chatListViewModel.emptyStateMessage)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading chats...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Inline Chat List Item View

struct InlineChatListItemView: View {
    let chat: Chat
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    @Default(.colorTheme) private var colorTheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Provider icon
            Image(systemName: providerIcon)
                .font(.system(size: 16))
                .foregroundColor(providerColor)
                .frame(width: 24, height: 24)
            
            // Chat info
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let preview = chat.lastMessagePreview {
                    Text(preview)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Time
            Text(chat.relativeUpdatedDate)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return colorTheme.color.opacity(0.15)
        } else if isHovering {
            return Color.primary.opacity(0.05)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return colorTheme.color.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var providerIcon: String {
        switch chat.llmProvider {
        case .openai:
            return "brain"
        case .anthropic:
            return "ant.circle"
        case .google:
            return "sparkle"
        case .local:
            return "desktopcomputer"
        }
    }
    
    private var providerColor: Color {
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


// MARK: - Preview

#if DEBUG
struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
            .frame(width: 400, height: 600)
    }
}
#endif