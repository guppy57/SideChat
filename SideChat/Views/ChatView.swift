import SwiftUI
import Defaults

// MARK: - Chat View

/// Main chat interface that displays a scrollable list of messages
/// with bottom-up layout and auto-scrolling to latest messages
struct ChatView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: ChatViewModel
    @State private var userIsScrolling = false
    @State private var refreshID = UUID()
    
    // MARK: - Body
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                VStack(spacing: 0) {
                    // Top buffer to allow scrolling content below gradient
                    Color.clear
                        .frame(height: 30)
                    
                    // Spacer to push content to bottom
                    Spacer(minLength: 0)
                    
                    // Messages container with lazy loading for performance
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(
                                message: message,
                                onDelete: {
                                    // Delay to allow context menu to dismiss properly
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        viewModel.deleteMessage(id: message.id)
                                        // Force view refresh to reset context menu state
                                        refreshID = UUID()
                                    }
                                }
                            )
                            .id(message.id)
                        }
                        
                        // Typing indicator
                        if viewModel.isTyping {
                            TypingIndicatorView()
                                .id("typing-indicator")
                        }
                    }
                    .id(refreshID) // Force refresh when ID changes
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // Bottom buffer to allow scrolling content above gradient
                    Color.clear
                        .frame(height: 30)
                }
                .frame(maxWidth: .infinity)
                .onChange(of: viewModel.messages.count) {
                    // Auto-scroll to new messages (optimized)
                    if !userIsScrolling && !viewModel.messages.isEmpty {
                        // Use lighter animation for better performance
                        withAnimation(.easeOut(duration: 0.2)) {
                            if viewModel.isTyping {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            } else {
                                proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.isTyping) {
                    // Only animate typing indicator changes
                    if viewModel.isTyping && !userIsScrolling {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("typing-indicator", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.throttledScrollUpdate) {
                    // Optimized streaming scroll with reduced animation overhead
                    if !userIsScrolling && viewModel.currentStreamingMessage != nil {
                        // No animation during streaming for maximum performance
                        if viewModel.isTyping {
                            proxy.scrollTo("typing-indicator", anchor: .bottom)
                        } else if let lastMessage = viewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.shouldScrollToBottom) { shouldScroll in
                    if shouldScroll && !viewModel.messages.isEmpty {
                        // Instant scroll without animation for chat switching performance
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        viewModel.resetScrollToBottom()
                    }
                }
                }
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(.bottom)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            // User is manually scrolling
                            if !userIsScrolling {
                                userIsScrolling = true
                            }
                        }
                        .onEnded { _ in
                            // Reset scrolling flag after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                userIsScrolling = false
                            }
                        }
                )
            }
            
        }
        .background(
            // Click-blocking transparent background
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .allowsHitTesting(true)
        )
        .mask(
            // Gradient mask for fade effect at top and bottom
            LinearGradient(
                gradient: Gradient(stops: [
                    // Top fade
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.6), location: 0.01),
                    .init(color: .black, location: 0.03),
                    // Middle solid
                    .init(color: .black, location: 0.97),
                    // Bottom fade
                    .init(color: .black.opacity(0.6), location: 0.99),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a preview-safe ChatViewModel that won't access the database
        let viewModel = ChatViewModel(autoLoadMessages: false)
        
        return ChatView(viewModel: viewModel)
            .frame(width: 550, height: 600)
            .background(Color.gray.opacity(0.1))
    }
}
#endif