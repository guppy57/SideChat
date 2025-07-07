import SwiftUI
import Defaults

// MARK: - Floating Toolbar

/// A floating toolbar that contains all control buttons, positioned below the input field
struct FloatingToolbar: View {
    
    // MARK: - Properties
    
    @Default(.colorTheme) private var colorTheme
    @State private var hoveredButton: ToolbarButton? = nil
    
    enum ToolbarButton: String, CaseIterable {
        case newChat = "plus.bubble"
        case chatList = "list.bullet"
        case pin = "pin"
        case settings = "gear"
        
        var tooltip: String {
            switch self {
            case .newChat: return "New Chat"
            case .chatList: return "Chat History"
            case .pin: return "Pin Sidebar"
            case .settings: return "Settings"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 16) {
            // New Chat button
            ToolbarButtonView(
                icon: ToolbarButton.newChat.rawValue,
                tooltip: ToolbarButton.newChat.tooltip,
                isHovered: hoveredButton == .newChat,
                action: createNewChat
            )
            .onHover { isHovered in
                hoveredButton = isHovered ? .newChat : nil
            }
            
            // Chat List button
            ToolbarButtonView(
                icon: ToolbarButton.chatList.rawValue,
                tooltip: ToolbarButton.chatList.tooltip,
                isHovered: hoveredButton == .chatList,
                action: showChatList
            )
            .onHover { isHovered in
                hoveredButton = isHovered ? .chatList : nil
            }
            
            Spacer()
            
            // Pin button
            ToolbarButtonView(
                icon: SidebarWindowController.shared.isSidebarPinned ? "pin.fill" : "pin",
                tooltip: SidebarWindowController.shared.isSidebarPinned ? "Unpin Sidebar" : "Pin Sidebar",
                isHovered: hoveredButton == .pin,
                action: togglePin
            )
            .onHover { isHovered in
                hoveredButton = isHovered ? .pin : nil
            }
            
            // Settings button
            ToolbarButtonView(
                icon: ToolbarButton.settings.rawValue,
                tooltip: ToolbarButton.settings.tooltip,
                isHovered: hoveredButton == .settings,
                action: showSettings
            )
            .onHover { isHovered in
                hoveredButton = isHovered ? .settings : nil
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Solid background for contrast
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
                
                // Blur overlay
                BlurredBackgroundView(
                    material: .titlebar,
                    opacity: 1.0
                )
                .cornerRadius(10)
            }
            .shadow(
                color: Color.black.opacity(0.3),
                radius: 12,
                x: 0,
                y: 4
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Actions
    
    private func createNewChat() {
        // TODO: Implement new chat creation
        print("Create new chat")
    }
    
    private func showChatList() {
        // TODO: Implement chat list display
        print("Show chat list")
    }
    
    private func togglePin() {
        let currentState = SidebarWindowController.shared.isSidebarPinned
        SidebarWindowController.shared.setSidebarPinned(!currentState)
    }
    
    private func showSettings() {
        NotificationCenter.default.post(name: .hotkeySettingsPanel, object: nil)
    }
}

// MARK: - Toolbar Button View

/// Individual button component for the toolbar
struct ToolbarButtonView: View {
    let icon: String
    let tooltip: String
    let isHovered: Bool
    let action: () -> Void
    
    @Default(.colorTheme) private var colorTheme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isHovered ? accentColor : Color.primary.opacity(0.7))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private var accentColor: Color {
        switch colorTheme {
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .orange: return .orange
        case .gray: return .gray
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FloatingToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            
            // Input field mockup
            HStack {
                TextField("Type a message...", text: .constant(""))
                    .textFieldStyle(PlainTextFieldStyle())
                
                Button(action: {}) {
                    Image(systemName: "paperplane.fill")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Floating toolbar
            FloatingToolbar()
        }
        .frame(width: 400, height: 200)
        .background(Color.gray.opacity(0.05))
    }
}
#endif