import XCTest
import Defaults
@testable import SideChat

final class SettingsManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset defaults before each test
        Defaults.removeAll()
    }
    
    override func tearDown() {
        // Reset defaults after each test
        Defaults.removeAll()
        super.tearDown()
    }
    
    // MARK: - DefaultsManager Tests
    
    @MainActor
    func testDefaultsManagerInitialization() {
        let manager = DefaultsManager.shared
        
        // Test default values are set correctly
        XCTAssertEqual(manager.sidebarEdge, .right)
        XCTAssertEqual(manager.sidebarTransparency, 0.8)
        XCTAssertEqual(manager.sidebarBlurIntensity, 0.5)
        XCTAssertEqual(manager.sidebarWidth, 400.0)
        XCTAssertEqual(manager.sidebarIsPinned, false)
        
        XCTAssertEqual(manager.showHideHotkey, "cmd+shift+space")
        XCTAssertEqual(manager.newChatHotkey, "cmd+n")
        
        XCTAssertEqual(manager.defaultLLMProvider, .openai)
        XCTAssertEqual(manager.openaiModel, "gpt-4")
        XCTAssertEqual(manager.anthropicModel, "claude-3-sonnet-20240229")
        XCTAssertEqual(manager.googleModel, "gemini-pro")
        
        XCTAssertEqual(manager.fontSize, 14.0)
        XCTAssertEqual(manager.fontFamily, "SF Pro Text")
        XCTAssertEqual(manager.colorTheme, .blue)
        
        XCTAssertEqual(manager.isFirstLaunch, true)
        XCTAssertEqual(manager.hasCompletedOnboarding, false)
        XCTAssertEqual(manager.lastOpenedVersion, "")
    }
    
    @MainActor
    func testDefaultsManagerUpdates() {
        let manager = DefaultsManager.shared
        
        // Test updating values
        manager.sidebarEdge = .left
        manager.sidebarTransparency = 0.6
        manager.fontSize = 16.0
        manager.defaultLLMProvider = .anthropic
        
        XCTAssertEqual(manager.sidebarEdge, .left)
        XCTAssertEqual(manager.sidebarTransparency, 0.6)
        XCTAssertEqual(manager.fontSize, 16.0)
        XCTAssertEqual(manager.defaultLLMProvider, .anthropic)
    }
    
    @MainActor
    func testDefaultsManagerReset() {
        let manager = DefaultsManager.shared
        
        // Modify some values
        manager.sidebarWidth = 500.0
        manager.fontSize = 18.0
        manager.defaultLLMProvider = .google
        
        // Reset to defaults
        manager.resetToDefaults()
        
        // Create new instance to verify reset
        let newManager = DefaultsManager.shared
        XCTAssertEqual(newManager.sidebarWidth, 400.0)
        XCTAssertEqual(newManager.fontSize, 14.0)
        XCTAssertEqual(newManager.defaultLLMProvider, .openai)
    }
    
    
    // MARK: - AppSettings Tests
    
    func testAppSettingsCreation() {
        // Set some specific values
        Defaults[.sidebarWidth] = 350.0
        Defaults[.fontSize] = 12.0
        Defaults[.defaultLLMProvider] = .google
        
        let settings = AppSettings.current()
        
        XCTAssertEqual(settings.sidebar.width, 350.0)
        XCTAssertEqual(settings.chatInterface.fontSize, 12.0)
        XCTAssertEqual(settings.llm.defaultProvider, .google)
    }
    
    func testAppSettingsValidation() {
        let validSettings = AppSettings.default()
        XCTAssertTrue(validSettings.isValid)
        XCTAssertTrue(validSettings.sidebar.isValid)
        XCTAssertTrue(validSettings.hotkeys.isValid)
        XCTAssertTrue(validSettings.llm.isValid)
        XCTAssertTrue(validSettings.chatInterface.isValid)
        XCTAssertTrue(validSettings.privacy.isValid)
        XCTAssertTrue(validSettings.export.isValid)
        XCTAssertTrue(validSettings.performance.isValid)
    }
    
    func testAppSettingsInvalidValues() {
        // Set invalid values
        Defaults[.sidebarWidth] = 100.0 // Too small
        Defaults[.sidebarTransparency] = 1.5 // Too high
        Defaults[.fontSize] = 5.0 // Too small
        Defaults[.autoDeleteDays] = 0 // Too small
        Defaults[.maxChatHistory] = 50 // Too small
        
        let settings = AppSettings.current()
        
        XCTAssertFalse(settings.sidebar.isValid)
        XCTAssertFalse(settings.chatInterface.isValid)
        XCTAssertFalse(settings.privacy.isValid)
        XCTAssertFalse(settings.performance.isValid)
        XCTAssertFalse(settings.isValid)
    }
    
    func testSettingsValidator() {
        // Set invalid values
        Defaults[.sidebarWidth] = 150.0
        Defaults[.fontSize] = 30.0
        Defaults[.autoDeleteDays] = 400
        
        let settings = AppSettings.current()
        let errors = SettingsValidator.validate(settings)
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains(.invalidSidebarWidth))
        XCTAssertTrue(errors.contains(.invalidFontSize))
        XCTAssertTrue(errors.contains(.invalidAutoDeleteDays))
    }
    
    
    // MARK: - Settings Migration Tests
    
    func testSettingsMigrationNeeded() {
        let migrator = SettingsMigrator.shared
        
        // Initial state should need migration
        XCTAssertTrue(migrator.needsMigration())
        XCTAssertEqual(migrator.getCurrentSchemaVersion(), 0)
        XCTAssertEqual(migrator.getTargetSchemaVersion(), 1)
    }
    
    func testSettingsMigrationExecution() async {
        let migrator = SettingsMigrator.shared
        
        // Clear any existing settings
        Defaults.removeAll()
        
        // Perform migration
        await migrator.migrateIfNeeded()
        
        // Check that migration was completed
        XCTAssertFalse(migrator.needsMigration())
        XCTAssertEqual(migrator.getCurrentSchemaVersion(), 1)
        
        // Check that default values are set
        XCTAssertEqual(Defaults[.sidebarWidth], 400.0)
        XCTAssertEqual(Defaults[.sidebarTransparency], 0.8)
        XCTAssertEqual(Defaults[.fontSize], 14.0)
        XCTAssertEqual(Defaults[.openaiModel], "gpt-4")
    }
    
    // MARK: - Settings Validation Service Tests
    
    @MainActor
    func testSettingsValidationService() async {
        let service = SettingsValidationService.shared
        
        // Set some invalid values
        Defaults[.sidebarWidth] = 100.0
        Defaults[.fontSize] = 5.0
        
        // Validate settings
        await service.validateSettings()
        
        XCTAssertTrue(service.hasValidationErrors)
        XCTAssertFalse(service.validationErrors.isEmpty)
        
        let widthValidation = service.validateSidebarWidth(100.0)
        XCTAssertFalse(widthValidation.isValid)
        XCTAssertNotNil(widthValidation.message)
        
        let fontValidation = service.validateFontSize(5.0)
        XCTAssertFalse(fontValidation.isValid)
        XCTAssertNotNil(fontValidation.message)
    }
    
    @MainActor
    func testSettingsRepair() async {
        let service = SettingsValidationService.shared
        
        // Set invalid values
        Defaults[.sidebarWidth] = 100.0
        Defaults[.sidebarTransparency] = 1.5
        Defaults[.fontSize] = 5.0
        Defaults[.autoDeleteDays] = 0
        
        // Repair settings
        await service.repairSettings()
        
        // Verify repaired values
        XCTAssertEqual(Defaults[.sidebarWidth], 200.0)
        XCTAssertEqual(Defaults[.sidebarTransparency], 1.0)
        XCTAssertEqual(Defaults[.fontSize], 8.0)
        XCTAssertEqual(Defaults[.autoDeleteDays], 1)
        
        // Validate again - should pass now
        await service.validateSettings()
        XCTAssertFalse(service.hasValidationErrors)
    }
    
    func testIndividualValidators() {
        let service = SettingsValidationService.shared
        
        // Test sidebar width validation
        XCTAssertTrue(service.validateSidebarWidth(300.0).isValid)
        XCTAssertFalse(service.validateSidebarWidth(100.0).isValid)
        XCTAssertFalse(service.validateSidebarWidth(900.0).isValid)
        
        // Test transparency validation
        XCTAssertTrue(service.validateTransparency(0.5).isValid)
        XCTAssertFalse(service.validateTransparency(-0.1).isValid)
        XCTAssertFalse(service.validateTransparency(1.1).isValid)
        
        // Test font size validation
        XCTAssertTrue(service.validateFontSize(14.0).isValid)
        XCTAssertFalse(service.validateFontSize(5.0).isValid)
        XCTAssertFalse(service.validateFontSize(30.0).isValid)
        
        // Test hotkey validation
        XCTAssertTrue(service.validateHotkey("cmd+shift+space").isValid)
        XCTAssertFalse(service.validateHotkey("").isValid)
        XCTAssertFalse(service.validateHotkey("   ").isValid)
        
        // Test export format validation
        XCTAssertTrue(service.validateExportFormat("markdown").isValid)
        XCTAssertTrue(service.validateExportFormat("json").isValid)
        XCTAssertTrue(service.validateExportFormat("txt").isValid)
        XCTAssertFalse(service.validateExportFormat("pdf").isValid)
    }
    
    func testModelNameValidation() {
        let service = SettingsValidationService.shared
        
        // Test OpenAI model validation
        let openaiValid = service.validateModelName("gpt-4", for: .openai)
        XCTAssertTrue(openaiValid.isValid)
        
        let openaiInvalid = service.validateModelName("invalid-model", for: .openai)
        XCTAssertTrue(openaiInvalid.isValid) // Should be warning, not invalid
        XCTAssertTrue(openaiInvalid.isWarning)
        
        // Test Anthropic model validation
        let anthropicValid = service.validateModelName("claude-3-sonnet", for: .anthropic)
        XCTAssertTrue(anthropicValid.isValid)
        
        // Test empty model names
        let emptyModel = service.validateModelName("", for: .openai)
        XCTAssertFalse(emptyModel.isValid)
    }
}