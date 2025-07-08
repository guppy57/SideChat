import SwiftUI
import Defaults

// MARK: - Chat List View

/// A popover-style view displaying a searchable list of chats
/// Similar to iMessage emoji picker in appearance and functionality
struct ChatListView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = ChatListViewModel()
    @Binding var isPresented: Bool
    @Binding var selectedChatId: UUID?
    @State private var isCreatingNewChat = false
    @State private var chatToDelete: Chat?
    @State private var showDeleteConfirmation = false
    @FocusState private var isSearchFocused: Bool
    
    @Default(.colorTheme) private var colorTheme
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            headerView
            
            Divider()
                .opacity(0.5)
            
            // Chat list or empty state
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasFilteredChats {
                chatListView
            } else {
                emptyStateView
            }
            
            Divider()
                .opacity(0.5)
            
            // Bottom toolbar
            toolbarView
        }
        .frame(width: 350, height: 500)
        .background(backgroundView)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onAppear {
            viewModel.selectedChatId = selectedChatId
            // Focus search field immediately
            isSearchFocused = true
        }
        .onChange(of: viewModel.selectedChatId) { newValue in
            if let chatId = newValue {
                selectedChatId = chatId
                isPresented = false
            }
        }
        .alert("Delete Chat", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                chatToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let chat = chatToDelete {
                    Task {
                        await viewModel.deleteChat(chat)
                        chatToDelete = nil
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(chatToDelete?.displayTitle ?? "this chat")\"? This action cannot be undone.")
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField("Search chats...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .focused($isSearchFocused)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
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
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .padding(12)
            
            // Filter options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Chat.FilterOption.allCases, id: \.self) { option in
                        FilterChip(
                            title: option.displayName,
                            isSelected: viewModel.filterOption == option,
                            action: { viewModel.filterOption = option }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 8)
        }
    }
    
    private var chatListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredChats) { chat in
                    ChatListItemView(
                        chat: chat,
                        isSelected: viewModel.selectedChatId == chat.id,
                        onSelect: {
                            viewModel.selectChat(chat)
                        },
                        onDelete: {
                            chatToDelete = chat
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(viewModel.emptyStateMessage)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if viewModel.filterOption == .all || viewModel.filterOption == .active {
                Button(action: createNewChat) {
                    Label("New Chat", systemImage: "plus.bubble")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.regular)
            }
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
    
    private var toolbarView: some View {
        HStack {
            // Sort menu
            Menu {
                ForEach(Chat.SortOption.allCases, id: \.self) { option in
                    Button(action: { viewModel.sortOption = option }) {
                        HStack {
                            Text(option.displayName)
                            if viewModel.sortOption == option {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12))
                    Text(viewModel.sortOption.displayName)
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .fixedSize()
            
            Spacer()
            
            // Stats
            if viewModel.hasChats {
                Text("\(viewModel.filteredChats.count) chats")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // New chat button
            Button(action: createNewChat) {
                Image(systemName: "plus.bubble")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colorTheme.color)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Create New Chat")
            .disabled(isCreatingNewChat)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private var backgroundView: some View {
        ZStack {
            // Base color
            Color(NSColor.controlBackgroundColor)
                .opacity(0.95)
            
            // Blur effect
            VisualEffectView(
                material: .popover,
                blendingMode: .behindWindow
            )
        }
    }
    
    // MARK: - Actions
    
    private func createNewChat() {
        isCreatingNewChat = true
        Task {
            if let newChat = await viewModel.createNewChat() {
                selectedChatId = newChat.id
                isPresented = false
            }
            isCreatingNewChat = false
        }
    }
}

// MARK: - Chat List Item View

struct ChatListItemView: View {
    let chat: Chat
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
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
            
            // Time and actions
            VStack(alignment: .trailing, spacing: 4) {
                Text(chat.relativeUpdatedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 8)
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

// MARK: - Filter Chip View

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @Default(.colorTheme) private var colorTheme
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? colorTheme.color : Color.primary.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView(
            isPresented: .constant(true),
            selectedChatId: .constant(nil)
        )
        .frame(width: 400, height: 600)
        .background(Color.gray.opacity(0.2))
    }
}
#endif