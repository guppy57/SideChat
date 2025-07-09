import Foundation
import Defaults

// MARK: - LLM Service Factory

/// Factory class for creating LLM services based on provider configurations
class LLMServiceFactory {
    
    /// Create an LLM service based on a provider configuration
    /// - Parameter configuration: The provider configuration
    /// - Returns: An LLM service instance if the provider is configured, nil otherwise
    @MainActor
    static func createService(for configuration: ProviderConfiguration) -> LLMServiceProtocol? {
        // Check if API key exists for the provider
        guard KeychainManager.hasAPIKey(for: configuration.provider) else {
            print("No API key found for provider: \(configuration.provider.displayName)")
            return nil
        }
        
        // Create appropriate service based on provider type
        switch configuration.provider {
        case .openai:
            return OpenAIService(configuration: configuration)
            
        case .anthropic:
            // TODO: Implement AnthropicService
            print("AnthropicService not yet implemented, using mock")
            return MockLLMService(provider: configuration.provider)
            
        case .google:
            // TODO: Implement GoogleAIService
            print("GoogleAIService not yet implemented, using mock")
            return MockLLMService(provider: configuration.provider)
            
        case .local:
            // TODO: Implement LocalModelService
            print("LocalModelService not yet implemented, using mock")
            return MockLLMService(provider: configuration.provider)
        }
    }
    
    /// Get the default service based on saved configurations
    /// - Returns: The default LLM service if available, nil otherwise
    @MainActor
    static func getDefaultService() -> (service: LLMServiceProtocol, configId: UUID)? {
        let configurations = Defaults[.providerConfigurations]
        
        // Find the default configuration
        guard let defaultConfig = configurations.first(where: { $0.isDefault }) else {
            print("No default provider configuration found")
            return nil
        }
        
        // Create service for the default configuration
        guard let service = createService(for: defaultConfig) else {
            print("Failed to create service for default configuration")
            return nil
        }
        
        return (service, defaultConfig.id)
    }
    
    /// Get all available services based on configured providers
    /// - Returns: Array of tuples containing services and their configuration IDs
    @MainActor
    static func getAllAvailableServices() -> [(service: LLMServiceProtocol, configId: UUID)] {
        let configurations = Defaults[.providerConfigurations]
        var services: [(LLMServiceProtocol, UUID)] = []
        
        for config in configurations {
            if let service = createService(for: config) {
                services.append((service, config.id))
            }
        }
        
        return services
    }
    
    /// Check if a specific provider type is configured
    /// - Parameter provider: The provider type to check
    /// - Returns: True if at least one configuration exists for this provider
    static func isProviderConfigured(_ provider: LLMProvider) -> Bool {
        let configurations = Defaults[.providerConfigurations]
        return configurations.contains { $0.provider == provider } && 
               KeychainManager.hasAPIKey(for: provider)
    }
    
    /// Get configuration by ID
    /// - Parameter configId: The configuration ID
    /// - Returns: The provider configuration if found
    static func getConfiguration(by configId: UUID) -> ProviderConfiguration? {
        let configurations = Defaults[.providerConfigurations]
        return configurations.first { $0.id == configId }
    }
    
    /// Get all configurations for a specific provider
    /// - Parameter provider: The provider type
    /// - Returns: Array of configurations for this provider
    static func getConfigurations(for provider: LLMProvider) -> [ProviderConfiguration] {
        let configurations = Defaults[.providerConfigurations]
        return configurations.filter { $0.provider == provider }
    }
}