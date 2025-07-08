import SwiftUI
import Defaults

// MARK: - Chat View

/// Main chat interface that displays a scrollable list of messages
/// with bottom-up layout and auto-scrolling to latest messages
struct ChatView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: ChatViewModel
    @State private var userIsScrolling = false
    
    // MARK: - Body
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                VStack(spacing: 0) {
                    // Spacer to push content to bottom
                    Spacer(minLength: 0)
                    
                    // Messages container
                    VStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                        
                        // Typing indicator
                        if viewModel.isTyping {
                            TypingIndicatorView()
                                .id("typing-indicator")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // Bottom buffer to allow scrolling content above gradient
                    Color.clear
                        .frame(height: 30)
                }
                .frame(maxWidth: .infinity)
                .onChange(of: viewModel.messages.count) {
                    // Auto-scroll to new messages
                    if !userIsScrolling {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if viewModel.isTyping {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            } else {
                                proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.isTyping) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if viewModel.isTyping {
                            proxy.scrollTo("typing-indicator", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.throttledScrollUpdate) {
                    // Auto-scroll during streaming if user isn't manually scrolling
                    if !userIsScrolling {
                        // Use faster animation during streaming for more responsive scrolling
                        let animationDuration = viewModel.currentStreamingMessage != nil ? 0.1 : 0.2
                        
                        withAnimation(.easeInOut(duration: animationDuration)) {
                            if viewModel.isTyping {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            } else if let lastMessage = viewModel.messages.last {
                                // Always use bottom anchor for consistent scrolling
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
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
            // Gradient mask for fade effect at bottom
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.97),
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
        ChatView(viewModel: ChatViewModel())
            .frame(width: 550, height: 600)
            .background(Color.gray.opacity(0.1))
    }
}
#endif