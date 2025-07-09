import Foundation
import KeychainAccess
import Defaults

// MARK: - Keychain Manager

/// Manages secure storage of API keys using the Keychain
/// This ensures API keys are never stored in UserDefaults or other insecure locations
class KeychainManager {
    
    // MARK: - Properties
    
    private static let keychain = Keychain(service: "com.armaangupta57.SideChat.apikeys")
        .accessibility(.whenUnlockedThisDeviceOnly)
    
    // MARK: - API Key Management
    
    /// Store an API key for a specific provider
    /// - Parameters:
    ///   - apiKey: The API key to store
    ///   - provider: The LLM provider
    static func setAPIKey(_ apiKey: String, for provider: LLMProvider) throws {
        let key = keyIdentifier(for: provider)
        
        // Validate API key is not empty
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KeychainError.invalidAPIKey
        }
        
        // Store in keychain
        try keychain.set(apiKey, key: key)
        
        // Update status in Defaults
        updateConfigurationStatus(for: provider, isConfigured: true)
    }
    
    /// Retrieve an API key for a specific provider
    /// - Parameter provider: The LLM provider
    /// - Returns: The API key if it exists, nil otherwise
    static func getAPIKey(for provider: LLMProvider) -> String? {
        let key = keyIdentifier(for: provider)
        return try? keychain.getString(key)
    }
    
    /// Delete an API key for a specific provider
    /// - Parameter provider: The LLM provider
    static func deleteAPIKey(for provider: LLMProvider) throws {
        let key = keyIdentifier(for: provider)
        try keychain.remove(key)
        
        // Update status in Defaults
        updateConfigurationStatus(for: provider, isConfigured: false)
    }
    
    /// Check if an API key exists for a specific provider
    /// - Parameter provider: The LLM provider
    /// - Returns: true if an API key is stored, false otherwise
    static func hasAPIKey(for provider: LLMProvider) -> Bool {
        return getAPIKey(for: provider) != nil
    }
    
    /// Delete all stored API keys
    static func deleteAllAPIKeys() throws {
        for provider in LLMProvider.allCases {
            if hasAPIKey(for: provider) {
                try deleteAPIKey(for: provider)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Generate a unique key identifier for each provider
    private static func keyIdentifier(for provider: LLMProvider) -> String {
        switch provider {
        case .openai:
            return "openai-api-key"
        case .anthropic:
            return "anthropic-api-key"
        case .google:
            return "google-ai-api-key"
        case .local:
            return "local-model-path"
        }
    }
    
    /// Update the configuration status in Defaults
    private static func updateConfigurationStatus(for provider: LLMProvider, isConfigured: Bool) {
        switch provider {
        case .openai:
            Defaults[.hasConfiguredOpenAI] = isConfigured
        case .anthropic:
            Defaults[.hasConfiguredAnthropic] = isConfigured
        case .google:
            Defaults[.hasConfiguredGoogleAI] = isConfigured
        case .local:
            Defaults[.hasConfiguredLocalModel] = isConfigured
        }
    }
}

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case invalidAPIKey
    case keychainAccessFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "The API key cannot be empty"
        case .keychainAccessFailed(let error):
            return "Failed to access keychain: \(error.localizedDescription)"
        }
    }
}