import Foundation
import SwiftUI
import Defaults

// MARK: - Settings Validation Service

class SettingsValidationService: ObservableObject {
    static let shared = SettingsValidationService()
    
    @Published var validationErrors: [ValidationError] = []
    @Published var isValidating = false
    @Published var hasValidationErrors = false
    
    private init() {}
    
    // MARK: - Real-time Validation
    
    @MainActor
    func validateSettings() async {
        isValidating = true
        defer { isValidating = false }
        
        let settings = AppSettings.current()
        let errors = SettingsValidator.validate(settings)
        
        self.validationErrors = errors
        self.hasValidationErrors = !errors.isEmpty
    }
    
    func validateSetting<T>(_ keyPath: KeyPath<AppSettings, T>, value: T) -> [ValidationError] {
        // Create a temporary settings object with the new value to validate
        let currentSettings = AppSettings.current()
        // Note: This is simplified - in practice you'd need to update the specific property
        return SettingsValidator.validate(currentSettings)
    }
    
    // MARK: - Individual Setting Validation
    
    func validateSidebarWidth(_ width: Double) -> ValidationResult {
        if width < 200.0 {
            return .invalid("Sidebar width cannot be less than 200 pixels")
        } else if width > 800.0 {
            return .invalid("Sidebar width cannot be more than 800 pixels")
        }
        return .valid
    }
    
    func validateTransparency(_ transparency: Double) -> ValidationResult {
        if transparency < 0.0 || transparency > 1.0 {
            return .invalid("Transparency must be between 0% and 100%")
        }
        return .valid
    }
    
    func validateBlurIntensity(_ intensity: Double) -> ValidationResult {
        if intensity < 0.0 || intensity > 1.0 {
            return .invalid("Blur intensity must be between 0% and 100%")
        }
        return .valid
    }
    
    func validateFontSize(_ fontSize: Double) -> ValidationResult {
        if fontSize < 8.0 {
            return .invalid("Font size cannot be smaller than 8 points")
        } else if fontSize > 24.0 {
            return .invalid("Font size cannot be larger than 24 points")
        }
        return .valid
    }
    
    func validateRequestTimeout(_ timeout: Double) -> ValidationResult {
        if timeout <= 0.0 {
            return .invalid("Request timeout must be greater than 0 seconds")
        } else if timeout > 600.0 {
            return .invalid("Request timeout cannot exceed 10 minutes")
        }
        return .valid
    }
    
    func validateAutoDeleteDays(_ days: Int) -> ValidationResult {
        if days < 1 {
            return .invalid("Auto-delete period must be at least 1 day")
        } else if days > 365 {
            return .invalid("Auto-delete period cannot exceed 365 days")
        }
        return .valid
    }
    
    func validateMaxChatHistory(_ count: Int) -> ValidationResult {
        if count < 100 {
            return .invalid("Chat history limit must be at least 100 messages")
        } else if count > 10000 {
            return .invalid("Chat history limit cannot exceed 10,000 messages")
        }
        return .valid
    }
    
    func validateHotkey(_ hotkey: String) -> ValidationResult {
        if hotkey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid("Hotkey cannot be empty")
        }
        
        // Basic hotkey format validation
        let components = hotkey.lowercased().components(separatedBy: "+")
        let validModifiers = ["cmd", "shift", "alt", "ctrl", "option", "command"]
        let hasValidModifier = components.dropLast().contains { validModifiers.contains($0) }
        
        if !hasValidModifier && components.count > 1 {
            return .invalid("Hotkey must include a valid modifier (cmd, shift, alt, ctrl)")
        }
        
        return .valid
    }
    
    func validateModelName(_ modelName: String, for provider: LLMProvider) -> ValidationResult {
        if modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid("\(provider.displayName) model name cannot be empty")
        }
        
        // Provider-specific validation
        switch provider {
        case .openai:
            let validPrefixes = ["gpt-", "o1-", "text-"]
            if !validPrefixes.contains(where: modelName.lowercased().hasPrefix) {
                return .warning("Model name may not be valid for OpenAI")
            }
        case .anthropic:
            if !modelName.lowercased().contains("claude") {
                return .warning("Model name may not be valid for Anthropic")
            }
        case .google:
            if !modelName.lowercased().contains("gemini") && !modelName.lowercased().contains("palm") {
                return .warning("Model name may not be valid for Google AI")
            }
        case .local:
            // For local models, just check if path exists if it's a file path
            if modelName.hasPrefix("/") || modelName.hasPrefix("~") {
                let expandedPath = NSString(string: modelName).expandingTildeInPath
                if !FileManager.default.fileExists(atPath: expandedPath) {
                    return .warning("Local model file does not exist at specified path")
                }
            }
        }
        
        return .valid
    }
    
    func validateExportFormat(_ format: String) -> ValidationResult {
        let validFormats = ["markdown", "json", "txt"]
        if !validFormats.contains(format.lowercased()) {
            return .invalid("Export format must be one of: \(validFormats.joined(separator: ", "))")
        }
        return .valid
    }
    
    // MARK: - Settings Repair
    
    func repairSettings() async {
        isValidating = true
        defer { isValidating = false }
        
        // Get current settings and attempt to repair invalid values
        let currentSettings = AppSettings.current()
        
        // Repair sidebar settings
        if !currentSettings.sidebar.isValid {
            if currentSettings.sidebar.transparency < 0.0 {
                Defaults[.sidebarTransparency] = 0.0
            } else if currentSettings.sidebar.transparency > 1.0 {
                Defaults[.sidebarTransparency] = 1.0
            }
            
            if currentSettings.sidebar.blurIntensity < 0.0 {
                Defaults[.sidebarBlurIntensity] = 0.0
            } else if currentSettings.sidebar.blurIntensity > 1.0 {
                Defaults[.sidebarBlurIntensity] = 1.0
            }
            
            if currentSettings.sidebar.width < 200.0 {
                Defaults[.sidebarWidth] = 200.0
            } else if currentSettings.sidebar.width > 800.0 {
                Defaults[.sidebarWidth] = 800.0
            }
        }
        
        // Repair chat interface settings
        if !currentSettings.chatInterface.isValid {
            if currentSettings.chatInterface.fontSize < 8.0 {
                Defaults[.fontSize] = 8.0
            } else if currentSettings.chatInterface.fontSize > 24.0 {
                Defaults[.fontSize] = 24.0
            }
            
            if currentSettings.chatInterface.fontFamily.isEmpty {
                Defaults[.fontFamily] = "SF Pro Text"
            }
            
            if currentSettings.chatInterface.animationDuration < 0.1 {
                Defaults[.animationDuration] = 0.1
            } else if currentSettings.chatInterface.animationDuration > 2.0 {
                Defaults[.animationDuration] = 2.0
            }
        }
        
        // Repair LLM settings
        if !currentSettings.llm.isValid {
            if currentSettings.llm.openaiModel.isEmpty {
                Defaults[.openaiModel] = "gpt-4"
            }
            
            if currentSettings.llm.anthropicModel.isEmpty {
                Defaults[.anthropicModel] = "claude-3-sonnet-20240229"
            }
            
            if currentSettings.llm.googleModel.isEmpty {
                Defaults[.googleModel] = "gemini-pro"
            }
            
            if currentSettings.llm.requestTimeout <= 0.0 {
                Defaults[.requestTimeout] = 30.0
            } else if currentSettings.llm.requestTimeout > 600.0 {
                Defaults[.requestTimeout] = 600.0
            }
        }
        
        // Repair performance settings
        if !currentSettings.performance.isValid {
            if currentSettings.performance.maxChatHistory < 100 {
                Defaults[.maxChatHistory] = 100
            } else if currentSettings.performance.maxChatHistory > 10000 {
                Defaults[.maxChatHistory] = 10000
            }
        }
        
        // Repair privacy settings
        if !currentSettings.privacy.isValid {
            if currentSettings.privacy.autoDeleteDays < 1 {
                Defaults[.autoDeleteDays] = 1
            } else if currentSettings.privacy.autoDeleteDays > 365 {
                Defaults[.autoDeleteDays] = 365
            }
        }
        
        // Repair export settings
        if !currentSettings.export.isValid {
            if !["markdown", "json", "txt"].contains(currentSettings.export.defaultFormat.lowercased()) {
                Defaults[.defaultExportFormat] = "markdown"
            }
        }
        
        // Re-validate after repairs
        await validateSettings()
    }
    
    // MARK: - Error Reporting
    
    func getErrorsForCategory(_ category: SettingsCategory) -> [ValidationError] {
        return validationErrors.filter { error in
            switch category {
            case .sidebar:
                return [.invalidTransparency, .invalidBlurIntensity, .invalidSidebarWidth].contains(error)
            case .hotkeys:
                return [.emptyShowHideHotkey, .emptyNewChatHotkey].contains(error)
            case .llm:
                return [.emptyOpenAIModel, .emptyAnthropicModel, .emptyGoogleModel, .invalidRequestTimeout].contains(error)
            case .chatInterface:
                return [.invalidFontSize, .emptyFontFamily, .invalidAnimationDuration].contains(error)
            case .privacy:
                return [.invalidAutoDeleteDays].contains(error)
            case .export:
                return [.invalidExportFormat].contains(error)
            case .performance:
                return [.invalidMaxChatHistory].contains(error)
            }
        }
    }
    
    func hasErrorsInCategory(_ category: SettingsCategory) -> Bool {
        return !getErrorsForCategory(category).isEmpty
    }
}

// MARK: - Validation Result Types

enum ValidationResult {
    case valid
    case invalid(String)
    case warning(String)
    
    var isValid: Bool {
        switch self {
        case .valid, .warning:
            return true
        case .invalid:
            return false
        }
    }
    
    var message: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message), .warning(let message):
            return message
        }
    }
    
    var isWarning: Bool {
        switch self {
        case .warning:
            return true
        default:
            return false
        }
    }
}

// MARK: - Settings Categories

enum SettingsCategory: CaseIterable {
    case sidebar
    case hotkeys
    case llm
    case chatInterface
    case privacy
    case export
    case performance
    
    var displayName: String {
        switch self {
        case .sidebar: return "Sidebar"
        case .hotkeys: return "Hotkeys"
        case .llm: return "LLM Settings"
        case .chatInterface: return "Chat Interface"
        case .privacy: return "Privacy"
        case .export: return "Export"
        case .performance: return "Performance"
        }
    }
}

// MARK: - SwiftUI Integration

struct ValidationErrorBanner: View {
    let errors: [ValidationError]
    let onDismiss: () -> Void
    let onRepair: () -> Void
    
    var body: some View {
        if !errors.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Settings Issues Found")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Repair", action: onRepair)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(errors.prefix(3), id: \.localizedDescription) { error in
                        Text("• \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if errors.count > 3 {
                        Text("• and \(errors.count - 3) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .transition(.slide)
        }
    }
}

struct ValidationStatusIndicator: View {
    let result: ValidationResult
    
    var body: some View {
        HStack(spacing: 4) {
            switch result {
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            case .invalid:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            
            if let message = result.message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Validated Input Components

struct ValidatedTextField: View {
    let title: String
    @Binding var text: String
    let validator: (String) -> ValidationResult
    let onValidationChange: ((ValidationResult) -> Void)?
    
    @State private var validationResult: ValidationResult = .valid
    
    init(
        _ title: String,
        text: Binding<String>,
        validator: @escaping (String) -> ValidationResult,
        onValidationChange: ((ValidationResult) -> Void)? = nil
    ) {
        self.title = title
        self._text = text
        self.validator = validator
        self.onValidationChange = onValidationChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text) { _, newValue in
                    validationResult = validator(newValue)
                    onValidationChange?(validationResult)
                }
            
            if !validationResult.isValid || validationResult.isWarning {
                ValidationStatusIndicator(result: validationResult)
            }
        }
        .onAppear {
            validationResult = validator(text)
            onValidationChange?(validationResult)
        }
    }
}

struct ValidatedSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let validator: (Double) -> ValidationResult
    let onValidationChange: ((ValidationResult) -> Void)?
    
    @State private var validationResult: ValidationResult = .valid
    
    init(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        validator: @escaping (Double) -> ValidationResult,
        onValidationChange: ((ValidationResult) -> Void)? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.validator = validator
        self.onValidationChange = onValidationChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range)
                .onChange(of: value) { _, newValue in
                    validationResult = validator(newValue)
                    onValidationChange?(validationResult)
                }
            
            if !validationResult.isValid || validationResult.isWarning {
                ValidationStatusIndicator(result: validationResult)
            }
        }
        .onAppear {
            validationResult = validator(value)
            onValidationChange?(validationResult)
        }
    }
}