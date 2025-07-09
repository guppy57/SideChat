import Foundation
import Defaults

/// DefaultsManager provides reactive access to user settings using the Defaults package
/// Handles all app configuration persistence and provides SwiftUI-compatible property wrappers

// MARK: - Defaults Keys Extension

extension Defaults.Keys {
    // MARK: - Sidebar Settings
    static let sidebarEdge = Key<SidebarEdge>("sidebarEdge", default: .right)
    static let sidebarEdgePosition = Key<String>("sidebarEdgePosition", default: "right")
    static let sidebarTransparency = Key<Double>("sidebarTransparency", default: 0.8)
    static let sidebarBlurIntensity = Key<Double>("sidebarBlurIntensity", default: 0.5)
    static let sidebarWidth = Key<Double>("sidebarWidth", default: 550.0)
    static let sidebarHeight = Key<Double>("sidebarHeight", default: 0.0) // 0 means auto-size to screen
    static let sidebarIsPinned = Key<Bool>("sidebarIsPinned", default: false)
    
    // MARK: - Hotkey Settings
    static let showHideHotkey = Key<String>("showHideHotkey", default: "cmd+shift+space")
    static let newChatHotkey = Key<String>("newChatHotkey", default: "cmd+n")
    
    // MARK: - LLM Settings
    static let defaultLLMProvider = Key<LLMProvider>("defaultLLMProvider", default: .openai)
    static let openaiModel = Key<String>("openaiModel", default: "gpt-4")
    static let anthropicModel = Key<String>("anthropicModel", default: "claude-3-sonnet-20240229")
    static let googleModel = Key<String>("googleModel", default: "gemini-pro")
    static let localModelPath = Key<String>("localModelPath", default: "")
    
    // MARK: - Chat Interface Settings
    static let fontSize = Key<Double>("fontSize", default: 14.0)
    static let fontFamily = Key<String>("fontFamily", default: "SF Pro Text")
    static let colorTheme = Key<ColorTheme>("colorTheme", default: .blue)
    static let showTypingIndicator = Key<Bool>("showTypingIndicator", default: true)
    static let enableMarkdownRendering = Key<Bool>("enableMarkdownRendering", default: true)
    static let enableImageUploads = Key<Bool>("enableImageUploads", default: true)
    
    // MARK: - Appearance Settings
    static let appearanceMode = Key<AppearanceMode>("appearanceMode", default: .system)
    static let autoHideSidebar = Key<Bool>("autoHideSidebar", default: true)
    static let enableAnimations = Key<Bool>("enableAnimations", default: true)
    static let animationDuration = Key<Double>("animationDuration", default: 0.3)
    
    // MARK: - Privacy Settings
    static let storeConversationHistory = Key<Bool>("storeConversationHistory", default: true)
    static let enableDataEncryption = Key<Bool>("enableDataEncryption", default: true)
    static let autoDeleteOldChats = Key<Bool>("autoDeleteOldChats", default: false)
    static let autoDeleteDays = Key<Int>("autoDeleteDays", default: 30)
    
    // MARK: - Export Settings
    static let defaultExportFormat = Key<String>("defaultExportFormat", default: "markdown")
    static let includeTimestamps = Key<Bool>("includeTimestamps", default: true)
    static let includeMetadata = Key<Bool>("includeMetadata", default: true)
    
    // MARK: - Performance Settings
    static let maxChatHistory = Key<Int>("maxChatHistory", default: 1000)
    static let enableStreamingResponses = Key<Bool>("enableStreamingResponses", default: true)
    static let requestTimeout = Key<Double>("requestTimeout", default: 360.0)
    static let performanceMaintenanceInterval = Key<TimeInterval>("performanceMaintenanceInterval", default: 7 * 24 * 60 * 60) // 7 days
    static let lastPerformanceMaintenance = Key<Date>("lastPerformanceMaintenance", default: Date.distantPast)
    static let enableAutomaticArchival = Key<Bool>("enableAutomaticArchival", default: true)
    static let archivalDays = Key<Int>("archivalDays", default: 90)
    static let maxMessagesPerChat = Key<Int>("maxMessagesPerChat", default: 10000)
    static let enableDatabaseOptimization = Key<Bool>("enableDatabaseOptimization", default: true)
    
    // MARK: - Onboarding & First Launch
    static let hasCompletedOnboarding = Key<Bool>("hasCompletedOnboarding", default: false)
    static let isFirstLaunch = Key<Bool>("isFirstLaunch", default: true)
    static let lastOpenedVersion = Key<String>("lastOpenedVersion", default: "")
    
    // MARK: - Feature Flags
    static let enableBetaFeatures = Key<Bool>("enableBetaFeatures", default: false)
    static let enableDebugMode = Key<Bool>("enableDebugMode", default: false)
    static let enableAnalytics = Key<Bool>("enableAnalytics", default: false)
    
    // MARK: - API Key Status (Note: actual keys are stored in Keychain)
    static let hasConfiguredOpenAI = Key<Bool>("hasConfiguredOpenAI", default: false)
    static let hasConfiguredAnthropic = Key<Bool>("hasConfiguredAnthropic", default: false)
    static let hasConfiguredGoogleAI = Key<Bool>("hasConfiguredGoogleAI", default: false)
    static let hasConfiguredLocalModel = Key<Bool>("hasConfiguredLocalModel", default: false)
    static let lastAPIKeyCheck = Key<Date>("lastAPIKeyCheck", default: Date.distantPast)
    
    // MARK: - Selected Models
    static let selectedOpenAIModel = Key<String>("selectedOpenAIModel", default: "gpt-4-turbo-preview")
    static let selectedAnthropicModel = Key<String>("selectedAnthropicModel", default: "claude-3-opus-20240229")
    static let selectedGoogleModel = Key<String>("selectedGoogleModel", default: "gemini-pro")
    
    // MARK: - Provider Configurations
    static let providerConfigurations = Key<[ProviderConfiguration]>("providerConfigurations", default: [])
}

// MARK: - DefaultsManager Utility Class

class DefaultsManager: ObservableObject {
    static let shared = DefaultsManager()
    
    private init() {}
    
    // MARK: - Sidebar Settings
    @Default(.sidebarEdge) var sidebarEdge
    @Default(.sidebarEdgePosition) var sidebarEdgePosition
    @Default(.sidebarTransparency) var sidebarTransparency
    @Default(.sidebarBlurIntensity) var sidebarBlurIntensity
    @Default(.sidebarWidth) var sidebarWidth
    @Default(.sidebarHeight) var sidebarHeight
    @Default(.sidebarIsPinned) var sidebarIsPinned
    
    // MARK: - Hotkey Settings
    @Default(.showHideHotkey) var showHideHotkey
    @Default(.newChatHotkey) var newChatHotkey
    
    // MARK: - LLM Settings
    @Default(.defaultLLMProvider) var defaultLLMProvider
    @Default(.openaiModel) var openaiModel
    @Default(.anthropicModel) var anthropicModel
    @Default(.googleModel) var googleModel
    @Default(.localModelPath) var localModelPath
    
    // MARK: - Chat Interface Settings
    @Default(.fontSize) var fontSize
    @Default(.fontFamily) var fontFamily
    @Default(.colorTheme) var colorTheme
    @Default(.showTypingIndicator) var showTypingIndicator
    @Default(.enableMarkdownRendering) var enableMarkdownRendering
    @Default(.enableImageUploads) var enableImageUploads
    
    // MARK: - Appearance Settings
    @Default(.appearanceMode) var appearanceMode
    @Default(.autoHideSidebar) var autoHideSidebar
    @Default(.enableAnimations) var enableAnimations
    @Default(.animationDuration) var animationDuration
    
    // MARK: - Privacy Settings
    @Default(.storeConversationHistory) var storeConversationHistory
    @Default(.enableDataEncryption) var enableDataEncryption
    @Default(.autoDeleteOldChats) var autoDeleteOldChats
    @Default(.autoDeleteDays) var autoDeleteDays
    
    // MARK: - Export Settings
    @Default(.defaultExportFormat) var defaultExportFormat
    @Default(.includeTimestamps) var includeTimestamps
    @Default(.includeMetadata) var includeMetadata
    
    // MARK: - Performance Settings
    @Default(.maxChatHistory) var maxChatHistory
    @Default(.enableStreamingResponses) var enableStreamingResponses
    @Default(.requestTimeout) var requestTimeout
    @Default(.performanceMaintenanceInterval) var performanceMaintenanceInterval
    @Default(.lastPerformanceMaintenance) var lastPerformanceMaintenance
    @Default(.enableAutomaticArchival) var enableAutomaticArchival
    @Default(.archivalDays) var archivalDays
    @Default(.maxMessagesPerChat) var maxMessagesPerChat
    @Default(.enableDatabaseOptimization) var enableDatabaseOptimization
    
    // MARK: - Onboarding & First Launch
    @Default(.hasCompletedOnboarding) var hasCompletedOnboarding
    @Default(.isFirstLaunch) var isFirstLaunch
    @Default(.lastOpenedVersion) var lastOpenedVersion
    
    // MARK: - Feature Flags
    @Default(.enableBetaFeatures) var enableBetaFeatures
    @Default(.enableDebugMode) var enableDebugMode
    @Default(.enableAnalytics) var enableAnalytics
    
    // MARK: - API Key Status
    @Default(.hasConfiguredOpenAI) var hasConfiguredOpenAI
    @Default(.hasConfiguredAnthropic) var hasConfiguredAnthropic
    @Default(.hasConfiguredGoogleAI) var hasConfiguredGoogleAI
    @Default(.hasConfiguredLocalModel) var hasConfiguredLocalModel
    @Default(.lastAPIKeyCheck) var lastAPIKeyCheck
    
    // MARK: - Selected Models
    @Default(.selectedOpenAIModel) var selectedOpenAIModel
    @Default(.selectedAnthropicModel) var selectedAnthropicModel
    @Default(.selectedGoogleModel) var selectedGoogleModel
    
    // MARK: - Utility Methods
    
    func resetToDefaults() {
        Defaults.removeAll()
    }
    
    // MARK: - API Key Status Updates
    
    func updateAPIKeyStatus() {
        hasConfiguredOpenAI = KeychainManager.hasAPIKey(for: .openai)
        hasConfiguredAnthropic = KeychainManager.hasAPIKey(for: .anthropic)
        hasConfiguredGoogleAI = KeychainManager.hasAPIKey(for: .google)
        hasConfiguredLocalModel = !localModelPath.isEmpty
        lastAPIKeyCheck = Date()
    }
    
    func clearAPIKeyStatus() {
        hasConfiguredOpenAI = false
        hasConfiguredAnthropic = false
        hasConfiguredGoogleAI = false
        hasConfiguredLocalModel = false
    }
}