//
//  SideChatTests.swift
//  SideChatTests
//
//  Created by Armaan Gupta on 7/7/25.
//

import Testing
@testable import SideChat

struct SideChatTests {

    @Test func appLaunch() async throws {
        // Test basic app functionality
        let app = SideChatApp()
        #expect(app != nil)
    }

    @Test func enumConformances() async throws {
        // Test that our enums conform to expected protocols  
        #expect(LLMProvider.openai is any Codable)
        #expect(SidebarEdge.left is any Codable)
        #expect(ColorTheme.blue is any Codable)
        #expect(AppearanceMode.system is any Codable)
    }

    @Test func modelCreation() async throws {
        // Test that models can be created successfully
        let chat = Chat.createNew(title: "Test", llmProvider: .openai, modelName: "gpt-4")
        #expect(chat.title == "Test")
        #expect(chat.llmProvider == .openai)
        #expect(chat.modelName == "gpt-4")
        
        let message = Message.createUserMessage(chatId: chat.id, content: "Hello")
        #expect(message.chatId == chat.id)
        #expect(message.content == "Hello")
        #expect(message.isUser == true)
    }

    @Test func settingsValidation() async throws {
        // Test settings validation
        let settings = AppSettings.default()
        #expect(settings.isValid == true)
        #expect(settings.sidebar.isValid == true)
        #expect(settings.llm.isValid == true)
        #expect(settings.chatInterface.isValid == true)
    }

}
