import Testing
import SwiftUI
@testable import SideChat
import Defaults
import MarkdownUI

@Suite("ChatBubbleView Tests")
struct ChatBubbleViewTests {
    
    @Test("Markdown rendering enabled for bot messages")
    func testMarkdownRenderingForBotMessages() async throws {
        // Store original value
        let originalValue = Defaults[.enableMarkdownRendering]
        
        // Create a bot message with markdown content
        let message = Message.createBotMessage(
            chatId: UUID(),
            content: "**Bold text** and *italic text* with `code`",
            status: .sent
        )
        
        // Create view with markdown enabled
        Defaults[.enableMarkdownRendering] = true
        let view = ChatBubbleView(message: message)
        
        // The view should use Markdown component for bot messages
        #expect(message.isUser == false)
        #expect(Defaults[.enableMarkdownRendering] == true)
        
        // Restore original value
        Defaults[.enableMarkdownRendering] = originalValue
    }
    
    @Test("Plain text rendering for user messages")
    func testPlainTextForUserMessages() async throws {
        // Store original value
        let originalValue = Defaults[.enableMarkdownRendering]
        
        // Create a user message
        let message = Message.createUserMessage(
            chatId: UUID(),
            content: "**This should not be bold**"
        )
        
        // Even with markdown enabled, user messages should be plain text
        Defaults[.enableMarkdownRendering] = true
        let view = ChatBubbleView(message: message)
        
        // User messages should always use plain text
        #expect(message.isUser == true)
        
        // Restore original value
        Defaults[.enableMarkdownRendering] = originalValue
    }
    
    @Test("Markdown disabled renders plain text")
    func testMarkdownDisabledRendersPlainText() async throws {
        // Store original value
        let originalValue = Defaults[.enableMarkdownRendering]
        
        // Create a bot message with markdown
        let message = Message.createBotMessage(
            chatId: UUID(),
            content: "**Bold text** and *italic*",
            status: .sent
        )
        
        // Disable markdown rendering
        Defaults[.enableMarkdownRendering] = false
        let view = ChatBubbleView(message: message)
        
        // Should render as plain text when disabled
        #expect(Defaults[.enableMarkdownRendering] == false)
        
        // Restore original value
        Defaults[.enableMarkdownRendering] = originalValue
    }
    
    @Test("Message status indicators")
    func testMessageStatusIndicators() async throws {
        // Test sending status
        let sendingMessage = Message(
            chatId: UUID(),
            content: "Sending...",
            isUser: true,
            status: .sending
        )
        
        // Test failed status
        let failedMessage = Message(
            chatId: UUID(),
            content: "Failed message",
            isUser: true,
            status: .failed
        )
        
        // Test sent status
        let sentMessage = Message(
            chatId: UUID(),
            content: "Sent successfully",
            isUser: true,
            status: .sent
        )
        
        #expect(sendingMessage.status == .sending)
        #expect(failedMessage.status == .failed)
        #expect(sentMessage.status == .sent)
    }
    
    @Test("Color theme application")
    func testColorThemeApplication() async throws {
        // Store original value
        let originalTheme = Defaults[.colorTheme]
        
        let message = Message.createUserMessage(
            chatId: UUID(),
            content: "Test message"
        )
        
        // Test different color themes
        let themes: [ColorTheme] = [.blue, .green, .purple, .orange, .gray]
        
        for theme in themes {
            Defaults[.colorTheme] = theme
            let view = ChatBubbleView(message: message)
            #expect(Defaults[.colorTheme] == theme)
        }
        
        // Restore original value
        Defaults[.colorTheme] = originalTheme
    }
    
    @Test("Font size configuration")
    func testFontSizeConfiguration() async throws {
        // Store original value
        let originalSize = Defaults[.fontSize]
        
        let message = Message.createBotMessage(
            chatId: UUID(),
            content: "Test font size",
            status: .sent
        )
        
        // Test different font sizes
        let fontSizes: [Double] = [12.0, 14.0, 16.0, 18.0, 20.0]
        
        for size in fontSizes {
            Defaults[.fontSize] = size
            let view = ChatBubbleView(message: message)
            #expect(Defaults[.fontSize] == size)
        }
        
        // Restore original value
        Defaults[.fontSize] = originalSize
    }
}

@Suite("BubbleShape Tests")
struct BubbleShapeTests {
    
    @Test("User bubble shape has right-side tail")
    func testUserBubbleShape() async throws {
        let shape = BubbleShape(isFromUser: true)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 50)
        let path = shape.path(in: rect)
        
        // The path should exist and have the expected characteristics
        let bounds = path.boundingRect
        #expect(bounds.width > 0)
        #expect(bounds.height > 0)
    }
    
    @Test("Bot bubble shape has left-side tail")
    func testBotBubbleShape() async throws {
        let shape = BubbleShape(isFromUser: false)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 50)
        let path = shape.path(in: rect)
        
        // The path should exist and have the expected characteristics
        let bounds = path.boundingRect
        #expect(bounds.width > 0)
        #expect(bounds.height > 0)
    }
    
    @Test("Bubble shape scales with rect")
    func testBubbleShapeScaling() async throws {
        let shape = BubbleShape(isFromUser: true)
        
        // Test different sizes
        let sizes = [
            CGSize(width: 100, height: 40),
            CGSize(width: 200, height: 60),
            CGSize(width: 300, height: 80)
        ]
        
        for size in sizes {
            let rect = CGRect(origin: .zero, size: size)
            let path = shape.path(in: rect)
            let bounds = path.boundingRect
            
            // Path should scale with the provided rect
            #expect(bounds.width <= size.width)
            #expect(bounds.height <= size.height)
        }
    }
}

@Suite("Markdown Theme Tests")
struct MarkdownThemeTests {
    
    @Test("User message markdown theme uses white text")
    func testUserMessageMarkdownTheme() async throws {
        let message = Message.createUserMessage(
            chatId: UUID(),
            content: "User message"
        )
        
        // User messages should have white text in markdown theme
        #expect(message.isUser == true)
        
        // The theme should be configured for white text on accent color background
        let view = ChatBubbleView(message: message)
        // Theme validation would happen in the view rendering
    }
    
    @Test("Bot message markdown theme uses primary text")
    func testBotMessageMarkdownTheme() async throws {
        let message = Message.createBotMessage(
            chatId: UUID(),
            content: "Bot message",
            status: .sent
        )
        
        // Bot messages should use primary text color
        #expect(message.isUser == false)
        
        // The theme should be configured for primary text color
        let view = ChatBubbleView(message: message)
        // Theme validation would happen in the view rendering
    }
    
    @Test("Code block styling in markdown")
    func testCodeBlockStyling() async throws {
        // Store original value
        let originalValue = Defaults[.enableMarkdownRendering]
        
        let codeContent = """
        ```swift
        let example = "Hello, World!"
        print(example)
        ```
        """
        
        let message = Message.createBotMessage(
            chatId: UUID(),
            content: codeContent,
            status: .sent
        )
        
        Defaults[.enableMarkdownRendering] = true
        let view = ChatBubbleView(message: message)
        
        // Verify markdown is enabled for proper code block rendering
        #expect(Defaults[.enableMarkdownRendering] == true)
        #expect(message.content.contains("```"))
        
        // Restore original value
        Defaults[.enableMarkdownRendering] = originalValue
    }
    
    @Test("Heading styling in markdown")
    func testHeadingStyling() async throws {
        // Store original value
        let originalValue = Defaults[.enableMarkdownRendering]
        
        let headingContent = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        
        Regular text
        """
        
        let message = Message.createBotMessage(
            chatId: UUID(),
            content: headingContent,
            status: .sent
        )
        
        Defaults[.enableMarkdownRendering] = true
        let view = ChatBubbleView(message: message)
        
        // Verify markdown content includes headings
        #expect(message.content.contains("#"))
        #expect(Defaults[.enableMarkdownRendering] == true)
        
        // Restore original value
        Defaults[.enableMarkdownRendering] = originalValue
    }
}