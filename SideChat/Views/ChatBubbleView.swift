import SwiftUI
import Defaults
import MarkdownUI

// MARK: - Chat Bubble View

/// Individual message bubble with iMessage-style appearance and tail
struct ChatBubbleView: View {
    
    // MARK: - Properties
    
    let message: Message
    @Default(.colorTheme) private var colorTheme
    @Default(.fontSize) private var fontSize
    @Default(.enableMarkdownRendering) private var enableMarkdownRendering
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Message bubble with tail
                ZStack(alignment: message.isUser ? .bottomTrailing : .bottomLeading) {
                    // Message content
                    Group {
                        if enableMarkdownRendering && !message.isUser {
                            // Use markdown for bot messages
                            Markdown(message.content)
                                .markdownTheme(markdownTheme)
                                .font(.system(size: CGFloat(fontSize)))
                        } else {
                            // Plain text for user messages or when markdown is disabled
                            Text(message.content)
                                .font(.system(size: CGFloat(fontSize)))
                                .foregroundColor(message.isUser ? .white : .primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                            ZStack {
                                BubbleShape(isFromUser: message.isUser)
                                    .fill(message.isUser ? accentColor.opacity(0.85) : Color(NSColor.controlBackgroundColor).opacity(0.95))
                                
                                BubbleShape(isFromUser: message.isUser)
                                    .fill(
                                        .regularMaterial.opacity(message.isUser ? 0.3 : 0.6)
                                    )
                            }
                        )
                        .overlay(
                            BubbleShape(isFromUser: message.isUser)
                                .stroke(bubbleBorder, lineWidth: 0.5)
                        )
                }
                
                // Timestamp and status
                HStack(spacing: 4) {
                    if message.isUser {
                        if message.status == .sending {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                        } else if message.status == .failed {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text(message.formattedTimestamp)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Computed Properties
    
    private var markdownTheme: Theme {
        if message.isUser {
            // User messages - white text theme
            return Theme()
                .text {
                    ForegroundColor(.white)
                    FontSize(CGFloat(fontSize))
                }
                .link {
                    ForegroundColor(.white)
                    UnderlineStyle(.single)
                }
                .code {
                    FontFamilyVariant(.monospaced)
                    FontSize(CGFloat(fontSize) * 0.9)
                    BackgroundColor(Color.white.opacity(0.2))
                }
                .codeBlock { configuration in
                    configuration.label
                        .padding()
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
        } else {
            // Bot messages - standard theme with custom styling
            return Theme()
                .text {
                    ForegroundColor(.primary)
                    FontSize(CGFloat(fontSize))
                }
                .link {
                    ForegroundColor(accentColor)
                    UnderlineStyle(.single)
                }
                .code {
                    FontFamilyVariant(.monospaced)
                    FontSize(CGFloat(fontSize) * 0.9)
                    BackgroundColor(Color.primary.opacity(0.1))
                }
                .codeBlock { configuration in
                    configuration.label
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
                .heading1 { configuration in
                    configuration.label
                        .markdownTextStyle {
                            FontWeight(.bold)
                            FontSize(CGFloat(fontSize) * 1.5)
                        }
                }
                .heading2 { configuration in
                    configuration.label
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(CGFloat(fontSize) * 1.3)
                        }
                }
                .heading3 { configuration in
                    configuration.label
                        .markdownTextStyle {
                            FontWeight(.medium)
                            FontSize(CGFloat(fontSize) * 1.1)
                        }
                }
        }
    }
    
    private var bubbleBorder: Color {
        if message.isUser {
            return accentColor.opacity(0.3)
        } else {
            return Color.primary.opacity(0.1)
        }
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

// MARK: - Bubble Shape

/// Custom shape for message bubbles with iMessage-style tail
struct BubbleShape: Shape {
    let isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let tailSize: CGFloat = 8
        let cornerRadius: CGFloat = 18
        
        return Path { path in
            if isFromUser {
                // User bubble (right side with tail)
                path.move(to: CGPoint(x: cornerRadius, y: 0))
                
                // Top edge
                path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
                
                // Top right corner
                path.addArc(
                    center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                
                // Right edge (with tail cutout)
                path.addLine(to: CGPoint(x: width, y: height - cornerRadius - tailSize))
                
                // Tail
                path.addCurve(
                    to: CGPoint(x: width, y: height),
                    control1: CGPoint(x: width, y: height - tailSize),
                    control2: CGPoint(x: width + tailSize/2, y: height)
                )
                
                // Bottom edge
                path.addLine(to: CGPoint(x: cornerRadius, y: height))
                
                // Bottom left corner
                path.addArc(
                    center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false
                )
                
                // Left edge
                path.addLine(to: CGPoint(x: 0, y: cornerRadius))
                
                // Top left corner
                path.addArc(
                    center: CGPoint(x: cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false
                )
                
                path.closeSubpath()
            } else {
                // Bot bubble (left side with tail)
                path.move(to: CGPoint(x: cornerRadius, y: 0))
                
                // Top edge
                path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
                
                // Top right corner
                path.addArc(
                    center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                
                // Right edge
                path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
                
                // Bottom right corner
                path.addArc(
                    center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false
                )
                
                // Bottom edge
                path.addLine(to: CGPoint(x: cornerRadius + tailSize, y: height))
                
                // Tail
                path.addCurve(
                    to: CGPoint(x: 0, y: height),
                    control1: CGPoint(x: cornerRadius, y: height),
                    control2: CGPoint(x: 0, y: height)
                )
                
                path.addLine(to: CGPoint(x: 0, y: height - tailSize))
                
                // Left edge (with tail)
                path.addLine(to: CGPoint(x: 0, y: cornerRadius))
                
                // Top left corner
                path.addArc(
                    center: CGPoint(x: cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false
                )
                
                path.closeSubpath()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ChatBubbleView(
                message: Message.createUserMessage(
                    chatId: UUID(),
                    content: "Hello! This is a user message with a tail on the right side."
                )
            )
            
            ChatBubbleView(
                message: Message.createBotMessage(
                    chatId: UUID(),
                    content: "This is a bot response with a tail on the left side. It can contain longer text and multiple lines to demonstrate how the bubble expands.",
                    status: .sent
                )
            )
            
            ChatBubbleView(
                message: Message.createUserMessage(
                    chatId: UUID(),
                    content: "Short message"
                )
            )
            
            ChatBubbleView(
                message: Message(
                    chatId: UUID(),
                    content: "Failed message example",
                    isUser: true,
                    status: .failed
                )
            )
        }
        .padding()
        .frame(width: 550, height: 400)
        .background(Color.gray.opacity(0.1))
    }
}
#endif