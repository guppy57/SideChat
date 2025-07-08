import SwiftUI
import Defaults

// MARK: - Typing Indicator View

/// Displays an animated typing indicator similar to iMessage
/// Shows three dots that animate with opacity changes
struct TypingIndicatorView: View {
    
    // MARK: - Properties
    
    @Default(.colorTheme) private var colorTheme
    @State private var animatingDot = 0
    
    private let animationDuration = 0.6
    private let dotSize: CGFloat = 8
    private let dotSpacing: CGFloat = 4
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Typing bubble aligned to left like bot messages
            HStack(spacing: dotSpacing) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: dotSize, height: dotSize)
                        .opacity(animatingDot == index ? 0.3 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: animationDuration)
                                .repeatForever()
                                .delay(Double(index) * (animationDuration / 3)),
                            value: animatingDot
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                BubbleBackground(isUser: false, colorTheme: colorTheme)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            .overlay(
                BubbleShape(isFromUser: false)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 4)
        .onAppear {
            // Start animation
            animatingDot = 0
            
            // Create continuous animation
            withAnimation(.linear(duration: animationDuration).repeatForever(autoreverses: false)) {
                animatingDot = 2
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TypingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Light mode
            TypingIndicatorView()
                .frame(width: 400)
                .background(Color.gray.opacity(0.1))
            
            // Dark mode
            TypingIndicatorView()
                .frame(width: 400)
                .background(Color.black)
                .environment(\.colorScheme, .dark)
            
            // In context with messages
            VStack(spacing: 12) {
                ChatBubbleView(
                    message: Message.createUserMessage(
                        chatId: UUID(),
                        content: "Can you help me with SwiftUI?"
                    )
                )
                
                TypingIndicatorView()
            }
            .frame(width: 400)
            .padding()
            .background(Color.gray.opacity(0.1))
        }
        .padding()
    }
}
#endif