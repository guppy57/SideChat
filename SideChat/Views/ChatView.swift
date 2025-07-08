import SwiftUI
import Defaults

// MARK: - Chat View

/// Main chat interface that displays a scrollable list of messages
/// with bottom-up layout and auto-scrolling to latest messages
struct ChatView: View {
    
    // MARK: - Properties
    
    @State private var messages: [Message] = []
    @State private var scrollToBottom = false
    
    let chatId: UUID
    
    // MARK: - Body
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Spacer to push content to bottom
                    Spacer(minLength: 0)
                    
                    // Messages container
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .frame(maxWidth: .infinity)
                .onChange(of: messages.count) { _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
                .onAppear {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
        }
        .background(Color.clear)
        .onAppear {
            loadMessages()
        }
    }
    
    // MARK: - Methods
    
    private func loadMessages() {
        // TODO: Load messages from database
        // For now, using mock data
        messages = [
            Message.createUserMessage(
                chatId: chatId,
                content: "Hello! Can you help me understand SwiftUI better?"
            ),
            Message.createBotMessage(
                chatId: chatId,
                content: "Of course! I'd be happy to help you understand SwiftUI better. SwiftUI is Apple's modern declarative framework for building user interfaces across all Apple platforms.\n\nWhat specific aspect of SwiftUI would you like to explore? Here are some areas we could dive into:\n\n• **Views and Modifiers** - The building blocks of SwiftUI\n• **State Management** - @State, @Binding, @ObservedObject, etc.\n• **Layout System** - Stacks, Grids, and custom layouts\n• **Animations** - Creating smooth, declarative animations\n• **Data Flow** - How data moves through your app\n\nWhat interests you most?",
                status: .sent
            ),
            Message.createUserMessage(
                chatId: chatId,
                content: "I'm particularly interested in understanding state management. When should I use @State vs @StateObject?"
            ),
            Message.createBotMessage(
                chatId: chatId,
                content: "Great question! Understanding when to use `@State` vs `@StateObject` is crucial for proper state management in SwiftUI. Let me break it down:\n\n## @State\n\nUse `@State` for:\n• **Simple value types** (String, Int, Bool, structs)\n• **View-local state** that doesn't need to be shared\n• **Temporary UI state** (toggle states, text field values)\n\n```swift\n@State private var isShowingAlert = false\n@State private var username = \"\"\n@State private var counter = 0\n```\n\n## @StateObject\n\nUse `@StateObject` for:\n• **Reference types** (classes conforming to ObservableObject)\n• **View models** that manage complex state\n• **State that needs to survive view updates**\n• **When you're creating/owning the object**\n\n```swift\n@StateObject private var viewModel = ChatViewModel()\n@StateObject private var networkManager = NetworkManager()\n```\n\n## Key Differences\n\n1. **Lifetime**: `@State` is tied to the view's lifetime, while `@StateObject` survives view updates\n2. **Type**: `@State` is for value types, `@StateObject` is for reference types\n3. **Ownership**: Use `@StateObject` when creating the object, `@ObservedObject` when receiving it\n\nWould you like to see more examples or explore other property wrappers like `@ObservedObject` or `@EnvironmentObject`?",
                status: .sent
            )
        ]
    }
    
    func addMessage(_ message: Message) {
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.append(message)
        }
    }
    
    func updateMessage(id: UUID, content: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content = content
        }
    }
    
    func updateMessageStatus(id: UUID, status: MessageStatus) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].status = status
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(chatId: UUID())
            .frame(width: 550, height: 600)
            .background(Color.gray.opacity(0.1))
    }
}
#endif