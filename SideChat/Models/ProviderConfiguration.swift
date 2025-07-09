import Foundation
import Defaults

// MARK: - Provider Configuration

/// Represents a configured LLM provider with its settings
struct ProviderConfiguration: Identifiable, Codable, Defaults.Serializable {
    let id: UUID
    let provider: LLMProvider
    var friendlyName: String
    var baseURL: String
    var selectedModel: String
    var isDefault: Bool
    
    init(
        id: UUID = UUID(),
        provider: LLMProvider,
        friendlyName: String? = nil,
        baseURL: String? = nil,
        selectedModel: String? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.provider = provider
        self.friendlyName = friendlyName ?? provider.displayName
        self.baseURL = baseURL ?? Self.defaultBaseURL(for: provider)
        self.selectedModel = selectedModel ?? Self.defaultModel(for: provider)
        self.isDefault = isDefault
    }
    
    // MARK: - Default Values
    
    static func defaultBaseURL(for provider: LLMProvider) -> String {
        switch provider {
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com"
        case .google:
            return "https://generativelanguage.googleapis.com"
        case .local:
            return "http://localhost:8080"
        }
    }
    
    static func defaultModel(for provider: LLMProvider) -> String {
        switch provider {
        case .openai:
            return "gpt-4-turbo-preview"
        case .anthropic:
            return "claude-3-opus-20240229"
        case .google:
            return "gemini-pro"
        case .local:
            return "local-model"
        }
    }
    
    // MARK: - Available Models
    
    static func availableModels(for provider: LLMProvider) -> [String] {
        switch provider {
        case .openai:
            return ["gpt-4-turbo-preview", "gpt-4", "gpt-3.5-turbo", "gpt-4-vision-preview"]
        case .anthropic:
            return ["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307"]
        case .google:
            return ["gemini-pro", "gemini-pro-vision"]
        case .local:
            return ["local-model"]
        }
    }
    
    // MARK: - API Key URLs
    
    static func apiKeyURL(for provider: LLMProvider) -> String {
        switch provider {
        case .openai:
            return "https://platform.openai.com/api-keys"
        case .anthropic:
            return "https://console.anthropic.com/account/keys"
        case .google:
            return "https://makersuite.google.com/app/apikey"
        case .local:
            return ""
        }
    }
}

// MARK: - Equatable

extension ProviderConfiguration: Equatable {
    static func == (lhs: ProviderConfiguration, rhs: ProviderConfiguration) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension ProviderConfiguration: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}