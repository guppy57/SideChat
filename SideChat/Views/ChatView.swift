import SwiftUI
import Defaults

// MARK: - Chat View

/// Main chat interface that displays a scrollable list of messages
/// with bottom-up layout and auto-scrolling to latest messages
struct ChatView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: ChatViewModel
    @State private var userIsScrolling = false
    @State private var lazyVStackFrame: CGRect = .zero
    
    // MARK: - Body
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                        
                    VStack(spacing: 0) {
                        // Top buffer to allow scrolling content below gradient
                        Color.clear
                            .frame(height: 30)
                        
                        // Messages container with bottom alignment
                        VStack {
                            Spacer(minLength: 0)
                            
                            GeometryReader { lazyGeo in
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.messages) { message in
                                        ChatBubbleView(
                                            message: message,
                                            onDelete: {
                                                print("🗑️ DELETE initiated for message: \(message.id)")
                                                print("  Current LazyVStack frame: \(lazyGeo.frame(in: .global))")
                                                print("  Current LazyVStack size: \(lazyGeo.size)")
                                                
                                                // Delay to allow context menu to dismiss properly
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                    viewModel.deleteMessage(id: message.id)
                                                }
                                            }
                                        )
                                        .id(message.id)
                                        .background(
                                            GeometryReader { bubbleGeo in
                                                Color.clear
                                                    .onAppear {
                                                        let frame = bubbleGeo.frame(in: .global)
                                                        print("🟩 Message \(message.id.uuidString.prefix(8)) frame: \(frame)")
                                                        print("  Height: \(frame.height), isUser: \(message.isUser)")
                                                    }
                                            }
                                        )
                                    }
                        
                                    // Typing indicator
                                    if viewModel.isTyping {
                                        TypingIndicatorView()
                                            .id("typing-indicator")
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, viewModel.messages.count < 5 ? 60 : 8)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear {
                                                lazyVStackFrame = geo.frame(in: .global)
                                                print("🟨 LazyVStack initial frame: \(lazyVStackFrame)")
                                            }
                                            .onChange(of: viewModel.messages.count) { _, count in
                                                lazyVStackFrame = geo.frame(in: .global)
                                                print("🟨 LazyVStack frame after change (count: \(count)): \(lazyVStackFrame)")
                                                print("  Size: \(geo.size)")
                                                print("  Bottom padding: \(count < 5 ? 60 : 8)")
                                            }
                                    }
                                )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle()) // Ensure proper hit testing area for entire VStack
                        
                        // Bottom buffer to allow scrolling content above gradient
                        Color.clear
                            .frame(height: 30)
                    }
                    .onChange(of: viewModel.messages.count) { _, count in
                        print("📊 SUMMARY after count change to \(count):")
                        print("  Total messages: \(viewModel.messages.count)")
                        print("  LazyVStack frame: \(lazyVStackFrame)")
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
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
                .onChange(of: viewModel.isTyping) { _, _ in
                    // Only animate typing indicator changes
                    if viewModel.isTyping && !userIsScrolling {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("typing-indicator", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.throttledScrollUpdate) { _, _ in
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
                .onChange(of: viewModel.shouldScrollToBottom) { _, shouldScroll in
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
            // Transparent background for visual structure
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .allowsHitTesting(false)
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