import Foundation
import Defaults

// MARK: - App Settings Model

/// Main application settings configuration using Defaults package for persistence
/// Provides structured access to all user preferences and app configuration

// MARK: - Settings Enums

enum SidebarEdge: String, CaseIterable, Defaults.Serializable {
    case left = "left"
    case right = "right"
    
    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

enum LLMProvider: String, CaseIterable, Defaults.Serializable, Codable {
    case openai = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case local = "local"
    
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google AI"
        case .local: return "Local Model"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Defaults.Serializable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum ColorTheme: String, CaseIterable, Defaults.Serializable {
    case blue = "blue"
    case green = "green"
    case purple = "purple"
    case orange = "orange"
    case gray = "gray"
    
    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .green: return "Green"
        case .purple: return "Purple"
        case .orange: return "Orange"
        case .gray: return "Gray"
        }
    }
}

// MARK: - App Settings Model

struct AppSettings {
    // MARK: - Sidebar Configuration
    struct SidebarSettings {
        let edge: SidebarEdge
        let transparency: Double
        let blurIntensity: Double
        let width: Double
        let isPinned: Bool
        let autoHide: Bool
        
        var isValid: Bool {
            transparency >= 0.0 && transparency <= 1.0 &&
            blurIntensity >= 0.0 && blurIntensity <= 1.0 &&
            width >= 200.0 && width <= 800.0
        }
    }
    
    // MARK: - Hotkey Configuration
    struct HotkeySettings {
        let showHideHotkey: String
        let newChatHotkey: String
        
        var isValid: Bool {
            !showHideHotkey.isEmpty && !newChatHotkey.isEmpty
        }
    }
    
    // MARK: - LLM Configuration
    struct LLMSettings {
        let defaultProvider: LLMProvider
        let openaiModel: String
        let anthropicModel: String
        let googleModel: String
        let localModelPath: String
        let enableStreamingResponses: Bool
        let requestTimeout: Double
        
        var isValid: Bool {
            !openaiModel.isEmpty &&
            !anthropicModel.isEmpty &&
            !googleModel.isEmpty &&
            requestTimeout > 0.0 && requestTimeout <= 600.0
        }
    }
    
    // MARK: - Chat Interface Configuration
    struct ChatInterfaceSettings {
        let fontSize: Double
        let fontFamily: String
        let colorTheme: ColorTheme
        let showTypingIndicator: Bool
        let enableMarkdownRendering: Bool
        let enableImageUploads: Bool
        let enableAnimations: Bool
        let animationDuration: Double
        
        var isValid: Bool {
            fontSize >= 8.0 && fontSize <= 24.0 &&
            !fontFamily.isEmpty &&
            animationDuration >= 0.1 && animationDuration <= 2.0
        }
    }
    
    // MARK: - Appearance Configuration
    struct AppearanceSettings {
        let mode: AppearanceMode
        let autoHideSidebar: Bool
        let enableAnimations: Bool
        
        var isValid: Bool {
            true // All appearance settings are inherently valid
        }
    }
    
    // MARK: - Privacy Configuration
    struct PrivacySettings {
        let storeConversationHistory: Bool
        let enableDataEncryption: Bool
        let autoDeleteOldChats: Bool
        let autoDeleteDays: Int
        
        var isValid: Bool {
            autoDeleteDays >= 1 && autoDeleteDays <= 365
        }
    }
    
    // MARK: - Export Configuration
    struct ExportSettings {
        let defaultFormat: String
        let includeTimestamps: Bool
        let includeMetadata: Bool
        
        var isValid: Bool {
            ["markdown", "json", "txt"].contains(defaultFormat.lowercased())
        }
    }
    
    // MARK: - Performance Configuration
    struct PerformanceSettings {
        let maxChatHistory: Int
        let enableStreamingResponses: Bool
        let requestTimeout: Double
        
        var isValid: Bool {
            maxChatHistory >= 100 && maxChatHistory <= 10000 &&
            requestTimeout > 0.0 && requestTimeout <= 600.0
        }
    }
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        let enableBetaFeatures: Bool
        let enableDebugMode: Bool
        let enableAnalytics: Bool
        
        var isValid: Bool {
            true // Feature flags are always valid
        }
    }
    
    // MARK: - Main Settings Structure
    let sidebar: SidebarSettings
    let hotkeys: HotkeySettings
    let llm: LLMSettings
    let chatInterface: ChatInterfaceSettings
    let appearance: AppearanceSettings
    let privacy: PrivacySettings
    let export: ExportSettings
    let performance: PerformanceSettings
    let features: FeatureFlags
    
    // MARK: - Validation
    var isValid: Bool {
        sidebar.isValid &&
        hotkeys.isValid &&
        llm.isValid &&
        chatInterface.isValid &&
        appearance.isValid &&
        privacy.isValid &&
        export.isValid &&
        performance.isValid &&
        features.isValid
    }
    
    // MARK: - Factory Methods
    static func current() -> AppSettings {
        // Access current values from Defaults directly
        // This avoids circular dependency with DefaultsManager
        
        return AppSettings(
            sidebar: SidebarSettings(
                edge: Defaults[.sidebarEdge],
                transparency: Defaults[.sidebarTransparency],
                blurIntensity: Defaults[.sidebarBlurIntensity],
                width: Defaults[.sidebarWidth],
                isPinned: Defaults[.sidebarIsPinned],
                autoHide: Defaults[.autoHideSidebar]
            ),
            hotkeys: HotkeySettings(
                showHideHotkey: Defaults[.showHideHotkey],
                newChatHotkey: Defaults[.newChatHotkey]
            ),
            llm: LLMSettings(
                defaultProvider: Defaults[.defaultLLMProvider],
                openaiModel: Defaults[.openaiModel],
                anthropicModel: Defaults[.anthropicModel],
                googleModel: Defaults[.googleModel],
                localModelPath: Defaults[.localModelPath],
                enableStreamingResponses: Defaults[.enableStreamingResponses],
                requestTimeout: Defaults[.requestTimeout]
            ),
            chatInterface: ChatInterfaceSettings(
                fontSize: Defaults[.fontSize],
                fontFamily: Defaults[.fontFamily],
                colorTheme: Defaults[.colorTheme],
                showTypingIndicator: Defaults[.showTypingIndicator],
                enableMarkdownRendering: Defaults[.enableMarkdownRendering],
                enableImageUploads: Defaults[.enableImageUploads],
                enableAnimations: Defaults[.enableAnimations],
                animationDuration: Defaults[.animationDuration]
            ),
            appearance: AppearanceSettings(
                mode: Defaults[.appearanceMode],
                autoHideSidebar: Defaults[.autoHideSidebar],
                enableAnimations: Defaults[.enableAnimations]
            ),
            privacy: PrivacySettings(
                storeConversationHistory: Defaults[.storeConversationHistory],
                enableDataEncryption: Defaults[.enableDataEncryption],
                autoDeleteOldChats: Defaults[.autoDeleteOldChats],
                autoDeleteDays: Defaults[.autoDeleteDays]
            ),
            export: ExportSettings(
                defaultFormat: Defaults[.defaultExportFormat],
                includeTimestamps: Defaults[.includeTimestamps],
                includeMetadata: Defaults[.includeMetadata]
            ),
            performance: PerformanceSettings(
                maxChatHistory: Defaults[.maxChatHistory],
                enableStreamingResponses: Defaults[.enableStreamingResponses],
                requestTimeout: Defaults[.requestTimeout]
            ),
            features: FeatureFlags(
                enableBetaFeatures: Defaults[.enableBetaFeatures],
                enableDebugMode: Defaults[.enableDebugMode],
                enableAnalytics: Defaults[.enableAnalytics]
            )
        )
    }
    
    static func `default`() -> AppSettings {
        return AppSettings(
            sidebar: SidebarSettings(
                edge: .right,
                transparency: 0.8,
                blurIntensity: 0.5,
                width: 400.0,
                isPinned: false,
                autoHide: true
            ),
            hotkeys: HotkeySettings(
                showHideHotkey: "cmd+shift+space",
                newChatHotkey: "cmd+n"
            ),
            llm: LLMSettings(
                defaultProvider: .openai,
                openaiModel: "gpt-4",
                anthropicModel: "claude-3-sonnet-20240229",
                googleModel: "gemini-pro",
                localModelPath: "",
                enableStreamingResponses: true,
                requestTimeout: 360.0
            ),
            chatInterface: ChatInterfaceSettings(
                fontSize: 14.0,
                fontFamily: "SF Pro Text",
                colorTheme: .blue,
                showTypingIndicator: true,
                enableMarkdownRendering: true,
                enableImageUploads: true,
                enableAnimations: true,
                animationDuration: 0.3
            ),
            appearance: AppearanceSettings(
                mode: .system,
                autoHideSidebar: true,
                enableAnimations: true
            ),
            privacy: PrivacySettings(
                storeConversationHistory: true,
                enableDataEncryption: true,
                autoDeleteOldChats: false,
                autoDeleteDays: 30
            ),
            export: ExportSettings(
                defaultFormat: "markdown",
                includeTimestamps: true,
                includeMetadata: true
            ),
            performance: PerformanceSettings(
                maxChatHistory: 1000,
                enableStreamingResponses: true,
                requestTimeout: 360.0
            ),
            features: FeatureFlags(
                enableBetaFeatures: false,
                enableDebugMode: false,
                enableAnalytics: false
            )
        )
    }
}

// MARK: - Settings Validation Helper

struct SettingsValidator {
    static func validate(_ settings: AppSettings) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Sidebar validation
        if !settings.sidebar.isValid {
            if settings.sidebar.transparency < 0.0 || settings.sidebar.transparency > 1.0 {
                errors.append(.invalidTransparency)
            }
            if settings.sidebar.blurIntensity < 0.0 || settings.sidebar.blurIntensity > 1.0 {
                errors.append(.invalidBlurIntensity)
            }
            if settings.sidebar.width < 200.0 || settings.sidebar.width > 800.0 {
                errors.append(.invalidSidebarWidth)
            }
        }
        
        // Hotkey validation
        if !settings.hotkeys.isValid {
            if settings.hotkeys.showHideHotkey.isEmpty {
                errors.append(.emptyShowHideHotkey)
            }
            if settings.hotkeys.newChatHotkey.isEmpty {
                errors.append(.emptyNewChatHotkey)
            }
        }
        
        // LLM validation
        if !settings.llm.isValid {
            if settings.llm.openaiModel.isEmpty {
                errors.append(.emptyOpenAIModel)
            }
            if settings.llm.anthropicModel.isEmpty {
                errors.append(.emptyAnthropicModel)
            }
            if settings.llm.googleModel.isEmpty {
                errors.append(.emptyGoogleModel)
            }
            if settings.llm.requestTimeout <= 0.0 || settings.llm.requestTimeout > 600.0 {
                errors.append(.invalidRequestTimeout)
            }
        }
        
        // Chat interface validation
        if !settings.chatInterface.isValid {
            if settings.chatInterface.fontSize < 8.0 || settings.chatInterface.fontSize > 24.0 {
                errors.append(.invalidFontSize)
            }
            if settings.chatInterface.fontFamily.isEmpty {
                errors.append(.emptyFontFamily)
            }
            if settings.chatInterface.animationDuration < 0.1 || settings.chatInterface.animationDuration > 2.0 {
                errors.append(.invalidAnimationDuration)
            }
        }
        
        // Privacy validation
        if !settings.privacy.isValid {
            if settings.privacy.autoDeleteDays < 1 || settings.privacy.autoDeleteDays > 365 {
                errors.append(.invalidAutoDeleteDays)
            }
        }
        
        // Export validation
        if !settings.export.isValid {
            if !["markdown", "json", "txt"].contains(settings.export.defaultFormat.lowercased()) {
                errors.append(.invalidExportFormat)
            }
        }
        
        // Performance validation
        if !settings.performance.isValid {
            if settings.performance.maxChatHistory < 100 || settings.performance.maxChatHistory > 10000 {
                errors.append(.invalidMaxChatHistory)
            }
            if settings.performance.requestTimeout <= 0.0 || settings.performance.requestTimeout > 600.0 {
                errors.append(.invalidRequestTimeout)
            }
        }
        
        return errors
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case invalidTransparency
    case invalidBlurIntensity
    case invalidSidebarWidth
    case emptyShowHideHotkey
    case emptyNewChatHotkey
    case emptyOpenAIModel
    case emptyAnthropicModel
    case emptyGoogleModel
    case invalidRequestTimeout
    case invalidFontSize
    case emptyFontFamily
    case invalidAnimationDuration
    case invalidAutoDeleteDays
    case invalidExportFormat
    case invalidMaxChatHistory
    
    var errorDescription: String? {
        switch self {
        case .invalidTransparency:
            return "Transparency must be between 0.0 and 1.0"
        case .invalidBlurIntensity:
            return "Blur intensity must be between 0.0 and 1.0"
        case .invalidSidebarWidth:
            return "Sidebar width must be between 200 and 800 pixels"
        case .emptyShowHideHotkey:
            return "Show/hide hotkey cannot be empty"
        case .emptyNewChatHotkey:
            return "New chat hotkey cannot be empty"
        case .emptyOpenAIModel:
            return "OpenAI model name cannot be empty"
        case .emptyAnthropicModel:
            return "Anthropic model name cannot be empty"
        case .emptyGoogleModel:
            return "Google AI model name cannot be empty"
        case .invalidRequestTimeout:
            return "Request timeout must be between 1 and 600 seconds"
        case .invalidFontSize:
            return "Font size must be between 8 and 24 points"
        case .emptyFontFamily:
            return "Font family cannot be empty"
        case .invalidAnimationDuration:
            return "Animation duration must be between 0.1 and 2.0 seconds"
        case .invalidAutoDeleteDays:
            return "Auto-delete days must be between 1 and 365"
        case .invalidExportFormat:
            return "Export format must be 'markdown', 'json', or 'txt'"
        case .invalidMaxChatHistory:
            return "Max chat history must be between 100 and 10,000 messages"
        }
    }
}

// MARK: - Settings Export/Import

extension AppSettings {
    func toDictionary() -> [String: Any] {
        return [
            "sidebar": [
                "edge": sidebar.edge.rawValue,
                "transparency": sidebar.transparency,
                "blurIntensity": sidebar.blurIntensity,
                "width": sidebar.width,
                "isPinned": sidebar.isPinned,
                "autoHide": sidebar.autoHide
            ],
            "hotkeys": [
                "showHideHotkey": hotkeys.showHideHotkey,
                "newChatHotkey": hotkeys.newChatHotkey
            ],
            "llm": [
                "defaultProvider": llm.defaultProvider.rawValue,
                "openaiModel": llm.openaiModel,
                "anthropicModel": llm.anthropicModel,
                "googleModel": llm.googleModel,
                "localModelPath": llm.localModelPath,
                "enableStreamingResponses": llm.enableStreamingResponses,
                "requestTimeout": llm.requestTimeout
            ],
            "chatInterface": [
                "fontSize": chatInterface.fontSize,
                "fontFamily": chatInterface.fontFamily,
                "colorTheme": chatInterface.colorTheme.rawValue,
                "showTypingIndicator": chatInterface.showTypingIndicator,
                "enableMarkdownRendering": chatInterface.enableMarkdownRendering,
                "enableImageUploads": chatInterface.enableImageUploads,
                "enableAnimations": chatInterface.enableAnimations,
                "animationDuration": chatInterface.animationDuration
            ],
            "appearance": [
                "mode": appearance.mode.rawValue,
                "autoHideSidebar": appearance.autoHideSidebar,
                "enableAnimations": appearance.enableAnimations
            ],
            "privacy": [
                "storeConversationHistory": privacy.storeConversationHistory,
                "enableDataEncryption": privacy.enableDataEncryption,
                "autoDeleteOldChats": privacy.autoDeleteOldChats,
                "autoDeleteDays": privacy.autoDeleteDays
            ],
            "export": [
                "defaultFormat": export.defaultFormat,
                "includeTimestamps": export.includeTimestamps,
                "includeMetadata": export.includeMetadata
            ],
            "performance": [
                "maxChatHistory": performance.maxChatHistory,
                "enableStreamingResponses": performance.enableStreamingResponses,
                "requestTimeout": performance.requestTimeout
            ],
            "features": [
                "enableBetaFeatures": features.enableBetaFeatures,
                "enableDebugMode": features.enableDebugMode,
                "enableAnalytics": features.enableAnalytics
            ]
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) throws -> AppSettings {
        guard let _ = dict["sidebar"] as? [String: Any],
              let _ = dict["hotkeys"] as? [String: Any],
              let _ = dict["llm"] as? [String: Any],
              let _ = dict["chatInterface"] as? [String: Any],
              let _ = dict["appearance"] as? [String: Any],
              let _ = dict["privacy"] as? [String: Any],
              let _ = dict["export"] as? [String: Any],
              let _ = dict["performance"] as? [String: Any],
              let _ = dict["features"] as? [String: Any] else {
            throw SettingsImportError.invalidFormat
        }
        
        // Parse all the sub-dictionaries and create the settings structure
        // This is a simplified version - in practice you'd want more robust parsing
        let settings = AppSettings.default() // Fallback to defaults for simplicity
        
        return settings
    }
}

enum SettingsImportError: LocalizedError {
    case invalidFormat
    case corruptedData
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Settings file format is invalid"
        case .corruptedData:
            return "Settings data is corrupted"
        }
    }
}