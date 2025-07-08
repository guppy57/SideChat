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
    private var chatListWindow: NSWindow?
    
    // MARK: - Initialization
    
    init(chatId: UUID? = nil) {
        let initialChatId = chatId ?? UUID()
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(chatId: initialChatId))
        _selectedChatId = State(initialValue: chatId)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area with chat view
            ChatView(viewModel: chatViewModel)
            
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
                    
                    // Provider badge
                    HStack(spacing: 4) {
                        Image(systemName: providerIcon(for: chat.llmProvider))
                            .font(.system(size: 11))
                        Text(chat.llmProvider.displayName)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(providerColor(for: chat.llmProvider))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(providerColor(for: chat.llmProvider).opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(providerColor(for: chat.llmProvider).opacity(0.3), lineWidth: 0.5)
                    )
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
                .allowsHitTesting(true)
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
    
    private var recentChats: [Chat] {
        // Get the most recent 20 chats, sorted by update date
        return chatListViewModel.chats
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(20)
            .map { $0 }
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
                
                Menu {
                    // Recent chats section
                    if !recentChats.isEmpty {
                        Section("Recent Chats") {
                            ForEach(recentChats) { chat in
                                Button(action: { 
                                    Task {
                                        await switchToChat(chat.id)
                                    }
                                }) {
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(chat.displayTitle)
                                                .lineLimit(1)
                                            if let preview = chat.lastMessagePreview {
                                                Text(preview)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    } icon: {
                                        Image(systemName: providerIcon(for: chat.llmProvider))
                                            .foregroundColor(providerColor(for: chat.llmProvider))
                                    }
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Action to open full list with search
                    Button(action: { openChatListWindow() }) {
                        Label("Search All Chats...", systemImage: "magnifyingglass")
                    }
                    
                    Divider()
                    
                    // New chat option
                    Button(action: createNewChat) {
                        Label("New Chat", systemImage: "plus.bubble")
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.7))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Chat History")
                
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
                
                Button(action: showSettings) {
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
    
    private func showChatListPopover() {
        openChatListWindow()
    }
    
    private func openChatListWindow() {
        // Create a binding that will notify us when to close the window
        let shouldCloseBinding = Binding<Bool>(
            get: { false },
            set: { _ in }
        )
        
        let chatListView = NavigationStack {
            ChatListView(
                isPresented: shouldCloseBinding,
                selectedChatId: $selectedChatId
            )
            .frame(minWidth: 400, minHeight: 500)
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Chat History"
        window.center()
        window.contentView = NSHostingView(rootView: chatListView)
        window.makeKeyAndOrderFront(nil)
        
        // Set minimum size
        window.minSize = NSSize(width: 400, height: 500)
        
        // Make the window level normal so it can be properly activated
        window.level = .normal
        
        // Ensure the window can become key
        window.isReleasedWhenClosed = false
    }
    
    private func togglePin() {
        let currentState = SidebarWindowController.shared.isSidebarPinned
        SidebarWindowController.shared.setSidebarPinned(!currentState)
    }
    
    private func showSettings() {
        NotificationCenter.default.post(name: .hotkeySettingsPanel, object: nil)
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

// MARK: - Preview

#if DEBUG
struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
            .frame(width: 400, height: 600)
    }
}
#endif