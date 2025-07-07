import Foundation
import Defaults

// MARK: - Settings Migration System

class SettingsMigrator {
    static let shared = SettingsMigrator()
    
    private let currentSchemaVersion = 1
    private let schemaVersionKey = "SettingsSchemaVersion"
    
    private init() {}
    
    // MARK: - Migration Entry Point
    
    func migrateIfNeeded() async {
        let currentVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)
        
        guard currentVersion < currentSchemaVersion else {
            return
        }
        
        print("Settings migration needed: v\(currentVersion) -> v\(currentSchemaVersion)")
        
        for version in (currentVersion + 1)...currentSchemaVersion {
            await performMigration(to: version)
        }
        
        UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
        print("Settings migration completed to v\(currentSchemaVersion)")
    }
    
    // MARK: - Version-Specific Migrations
    
    private func performMigration(to version: Int) async {
        print("Migrating settings to version \(version)")
        
        switch version {
        case 1:
            await migrateToVersion1()
        default:
            print("No migration defined for version \(version)")
        }
    }
    
    // MARK: - Migration Implementations
    
    private func migrateToVersion1() async {
        // Initial version - set up default values for any missing settings
        print("Performing initial settings setup...")
        
        // Ensure all defaults are properly initialized
        if Defaults[.sidebarEdge] == .right && Defaults[.sidebarWidth] == 0.0 {
            Defaults[.sidebarWidth] = 400.0
        }
        
        if Defaults[.sidebarTransparency] == 0 {
            Defaults[.sidebarTransparency] = 0.8
        }
        
        if Defaults[.sidebarBlurIntensity] == 0 {
            Defaults[.sidebarBlurIntensity] = 0.5
        }
        
        if Defaults[.fontSize] == 0 {
            Defaults[.fontSize] = 14.0
        }
        
        if Defaults[.fontFamily].isEmpty {
            Defaults[.fontFamily] = "SF Pro Text"
        }
        
        if Defaults[.requestTimeout] == 0 {
            Defaults[.requestTimeout] = 360.0
        }
        
        if Defaults[.maxChatHistory] == 0 {
            Defaults[.maxChatHistory] = 1000
        }
        
        if Defaults[.autoDeleteDays] == 0 {
            Defaults[.autoDeleteDays] = 30
        }
        
        if Defaults[.animationDuration] == 0 {
            Defaults[.animationDuration] = 0.3
        }
        
        if Defaults[.defaultExportFormat].isEmpty {
            Defaults[.defaultExportFormat] = "markdown"
        }
        
        if Defaults[.openaiModel].isEmpty {
            Defaults[.openaiModel] = "gpt-4"
        }
        
        if Defaults[.anthropicModel].isEmpty {
            Defaults[.anthropicModel] = "claude-3-sonnet-20240229"
        }
        
        if Defaults[.googleModel].isEmpty {
            Defaults[.googleModel] = "gemini-pro"
        }
        
        if Defaults[.showHideHotkey].isEmpty {
            Defaults[.showHideHotkey] = "cmd+shift+space"
        }
        
        if Defaults[.newChatHotkey].isEmpty {
            Defaults[.newChatHotkey] = "cmd+n"
        }
        
        print("Initial settings setup completed")
    }
    
    // MARK: - Future Migration Templates
    
    // Template for future migrations
    /*
    private func migrateToVersion2() async {
        // Example: Migrate old color scheme to new theme system
        if let oldColorScheme = UserDefaults.standard.string(forKey: "oldColorScheme") {
            switch oldColorScheme {
            case "blue":
                Defaults[.colorTheme] = .blue
            case "green":
                Defaults[.colorTheme] = .green
            default:
                Defaults[.colorTheme] = .blue
            }
            UserDefaults.standard.removeObject(forKey: "oldColorScheme")
        }
    }
    
    private func migrateToVersion3() async {
        // Example: Migrate old hotkey format to new format
        if let oldHotkey = UserDefaults.standard.string(forKey: "oldHotkeyFormat") {
            let newHotkey = convertOldHotkeyFormat(oldHotkey)
            Defaults[.showHideHotkey] = newHotkey
            UserDefaults.standard.removeObject(forKey: "oldHotkeyFormat")
        }
    }
    */
    
    // MARK: - Migration Utilities
    
    private func backupSettings() -> [String: Any] {
        return [
            "sidebarEdge": Defaults[.sidebarEdge].rawValue,
            "sidebarTransparency": Defaults[.sidebarTransparency],
            "sidebarBlurIntensity": Defaults[.sidebarBlurIntensity],
            "sidebarWidth": Defaults[.sidebarWidth],
            "fontSize": Defaults[.fontSize],
            "fontFamily": Defaults[.fontFamily],
            "colorTheme": Defaults[.colorTheme].rawValue,
            "appearanceMode": Defaults[.appearanceMode].rawValue,
            "defaultLLMProvider": Defaults[.defaultLLMProvider].rawValue,
            "openaiModel": Defaults[.openaiModel],
            "anthropicModel": Defaults[.anthropicModel],
            "googleModel": Defaults[.googleModel],
            "requestTimeout": Defaults[.requestTimeout],
            "maxChatHistory": Defaults[.maxChatHistory],
            "autoDeleteDays": Defaults[.autoDeleteDays],
            "showHideHotkey": Defaults[.showHideHotkey],
            "newChatHotkey": Defaults[.newChatHotkey],
            "enableAnimations": Defaults[.enableAnimations],
            "animationDuration": Defaults[.animationDuration],
            "defaultExportFormat": Defaults[.defaultExportFormat],
            "storeConversationHistory": Defaults[.storeConversationHistory],
            "enableDataEncryption": Defaults[.enableDataEncryption],
            "autoDeleteOldChats": Defaults[.autoDeleteOldChats],
            "autoHideSidebar": Defaults[.autoHideSidebar],
            "enableMarkdownRendering": Defaults[.enableMarkdownRendering],
            "enableImageUploads": Defaults[.enableImageUploads],
            "showTypingIndicator": Defaults[.showTypingIndicator],
            "includeTimestamps": Defaults[.includeTimestamps],
            "includeMetadata": Defaults[.includeMetadata],
            "enableStreamingResponses": Defaults[.enableStreamingResponses],
            "sidebarIsPinned": Defaults[.sidebarIsPinned],
            "localModelPath": Defaults[.localModelPath],
            "hasCompletedOnboarding": Defaults[.hasCompletedOnboarding],
            "isFirstLaunch": Defaults[.isFirstLaunch],
            "lastOpenedVersion": Defaults[.lastOpenedVersion],
            "enableBetaFeatures": Defaults[.enableBetaFeatures],
            "enableDebugMode": Defaults[.enableDebugMode],
            "enableAnalytics": Defaults[.enableAnalytics]
        ]
    }
    
    private func saveBackup(_ backup: [String: Any], for version: Int) {
        let backupKey = "SettingsBackup_v\(version)"
        UserDefaults.standard.set(backup, forKey: backupKey)
    }
    
    private func loadBackup(for version: Int) -> [String: Any]? {
        let backupKey = "SettingsBackup_v\(version)"
        return UserDefaults.standard.dictionary(forKey: backupKey)
    }
    
    private func validateMigration() -> Bool {
        let settings = AppSettings.current()
        let errors = SettingsValidator.validate(settings)
        
        if !errors.isEmpty {
            print("Migration validation failed with errors: \(errors)")
            return false
        }
        
        return true
    }
    
    private func rollbackMigration(to version: Int) {
        print("Rolling back migration to version \(version)")
        
        if let backup = loadBackup(for: version) {
            restoreFromBackup(backup)
        } else {
            print("No backup found for version \(version), using defaults")
            resetToDefaults()
        }
    }
    
    private func restoreFromBackup(_ backup: [String: Any]) {
        // Restore settings from backup
        if let edge = backup["sidebarEdge"] as? String,
           let sidebarEdge = SidebarEdge(rawValue: edge) {
            Defaults[.sidebarEdge] = sidebarEdge
        }
        
        if let transparency = backup["sidebarTransparency"] as? Double {
            Defaults[.sidebarTransparency] = transparency
        }
        
        if let blur = backup["sidebarBlurIntensity"] as? Double {
            Defaults[.sidebarBlurIntensity] = blur
        }
        
        if let width = backup["sidebarWidth"] as? Double {
            Defaults[.sidebarWidth] = width
        }
        
        if let fontSize = backup["fontSize"] as? Double {
            Defaults[.fontSize] = fontSize
        }
        
        if let fontFamily = backup["fontFamily"] as? String {
            Defaults[.fontFamily] = fontFamily
        }
        
        if let theme = backup["colorTheme"] as? String,
           let colorTheme = ColorTheme(rawValue: theme) {
            Defaults[.colorTheme] = colorTheme
        }
        
        if let mode = backup["appearanceMode"] as? String,
           let appearanceMode = AppearanceMode(rawValue: mode) {
            Defaults[.appearanceMode] = appearanceMode
        }
        
        if let provider = backup["defaultLLMProvider"] as? String,
           let llmProvider = LLMProvider(rawValue: provider) {
            Defaults[.defaultLLMProvider] = llmProvider
        }
        
        if let model = backup["openaiModel"] as? String {
            Defaults[.openaiModel] = model
        }
        
        if let model = backup["anthropicModel"] as? String {
            Defaults[.anthropicModel] = model
        }
        
        if let model = backup["googleModel"] as? String {
            Defaults[.googleModel] = model
        }
        
        if let timeout = backup["requestTimeout"] as? Double {
            Defaults[.requestTimeout] = timeout
        }
        
        if let maxHistory = backup["maxChatHistory"] as? Int {
            Defaults[.maxChatHistory] = maxHistory
        }
        
        if let deleteDays = backup["autoDeleteDays"] as? Int {
            Defaults[.autoDeleteDays] = deleteDays
        }
        
        if let showHotkey = backup["showHideHotkey"] as? String {
            Defaults[.showHideHotkey] = showHotkey
        }
        
        if let newHotkey = backup["newChatHotkey"] as? String {
            Defaults[.newChatHotkey] = newHotkey
        }
        
        if let animations = backup["enableAnimations"] as? Bool {
            Defaults[.enableAnimations] = animations
        }
        
        if let duration = backup["animationDuration"] as? Double {
            Defaults[.animationDuration] = duration
        }
        
        if let format = backup["defaultExportFormat"] as? String {
            Defaults[.defaultExportFormat] = format
        }
        
        if let store = backup["storeConversationHistory"] as? Bool {
            Defaults[.storeConversationHistory] = store
        }
        
        if let encrypt = backup["enableDataEncryption"] as? Bool {
            Defaults[.enableDataEncryption] = encrypt
        }
        
        if let autoDelete = backup["autoDeleteOldChats"] as? Bool {
            Defaults[.autoDeleteOldChats] = autoDelete
        }
        
        if let autoHide = backup["autoHideSidebar"] as? Bool {
            Defaults[.autoHideSidebar] = autoHide
        }
        
        if let markdown = backup["enableMarkdownRendering"] as? Bool {
            Defaults[.enableMarkdownRendering] = markdown
        }
        
        if let images = backup["enableImageUploads"] as? Bool {
            Defaults[.enableImageUploads] = images
        }
        
        if let typing = backup["showTypingIndicator"] as? Bool {
            Defaults[.showTypingIndicator] = typing
        }
        
        if let timestamps = backup["includeTimestamps"] as? Bool {
            Defaults[.includeTimestamps] = timestamps
        }
        
        if let metadata = backup["includeMetadata"] as? Bool {
            Defaults[.includeMetadata] = metadata
        }
        
        if let streaming = backup["enableStreamingResponses"] as? Bool {
            Defaults[.enableStreamingResponses] = streaming
        }
        
        if let pinned = backup["sidebarIsPinned"] as? Bool {
            Defaults[.sidebarIsPinned] = pinned
        }
        
        if let localPath = backup["localModelPath"] as? String {
            Defaults[.localModelPath] = localPath
        }
        
        if let onboarding = backup["hasCompletedOnboarding"] as? Bool {
            Defaults[.hasCompletedOnboarding] = onboarding
        }
        
        if let firstLaunch = backup["isFirstLaunch"] as? Bool {
            Defaults[.isFirstLaunch] = firstLaunch
        }
        
        if let version = backup["lastOpenedVersion"] as? String {
            Defaults[.lastOpenedVersion] = version
        }
        
        if let beta = backup["enableBetaFeatures"] as? Bool {
            Defaults[.enableBetaFeatures] = beta
        }
        
        if let debug = backup["enableDebugMode"] as? Bool {
            Defaults[.enableDebugMode] = debug
        }
        
        if let analytics = backup["enableAnalytics"] as? Bool {
            Defaults[.enableAnalytics] = analytics
        }
    }
    
    private func resetToDefaults() {
        print("Resetting all settings to defaults")
        Defaults.removeAll()
    }
    
    // MARK: - Migration Status
    
    func getCurrentSchemaVersion() -> Int {
        return UserDefaults.standard.integer(forKey: schemaVersionKey)
    }
    
    func getTargetSchemaVersion() -> Int {
        return currentSchemaVersion
    }
    
    func needsMigration() -> Bool {
        return getCurrentSchemaVersion() < currentSchemaVersion
    }
}

// MARK: - Migration Error Types

enum MigrationError: LocalizedError {
    case migrationFailed(version: Int)
    case validationFailed(errors: [ValidationError])
    case backupCorrupted(version: Int)
    case unknownVersion(version: Int)
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed(let version):
            return "Migration to version \(version) failed"
        case .validationFailed(let errors):
            return "Migration validation failed: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        case .backupCorrupted(let version):
            return "Backup for version \(version) is corrupted"
        case .unknownVersion(let version):
            return "Unknown migration version: \(version)"
        }
    }
}

// MARK: - Migration Notification

extension Notification.Name {
    static let settingsMigrationStarted = Notification.Name("SettingsMigrationStarted")
    static let settingsMigrationCompleted = Notification.Name("SettingsMigrationCompleted")
    static let settingsMigrationFailed = Notification.Name("SettingsMigrationFailed")
}

// MARK: - Migration Info

struct MigrationInfo {
    let fromVersion: Int
    let toVersion: Int
    let startTime: Date
    let endTime: Date?
    let success: Bool
    let errors: [String]
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}