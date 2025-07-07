import Foundation
import KeyboardShortcuts
import Defaults

// MARK: - KeyboardShortcuts.Name Extension

extension KeyboardShortcuts.Name {
    static let showHideSidebar = Self("showHideSidebar", default: .init(.space, modifiers: [.command, .shift]))
    static let newChat = Self("newChat", default: .init(.n, modifiers: [.command]))
    static let focusInput = Self("focusInput", default: .init(.f, modifiers: [.command]))
    static let clearChat = Self("clearChat", default: .init(.k, modifiers: [.command]))
    static let exportChat = Self("exportChat", default: .init(.e, modifiers: [.command]))
    static let togglePin = Self("togglePin", default: .init(.p, modifiers: [.command]))
    static let settingsPanel = Self("settingsPanel", default: .init(.comma, modifiers: [.command]))
}

// MARK: - HotkeyManager

/// Manages global keyboard shortcuts using the KeyboardShortcuts package
/// Integrates with SidebarWindowController for window management
class HotkeyManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = HotkeyManager()
    
    // MARK: - Properties
    private var isRegistered = false
    private weak var sidebarController: SidebarWindowController?
    
    // MARK: - Initialization
    
    private init() {
        setupHotkeys()
    }
    
    // MARK: - Setup
    
    func setupHotkeys() {
        guard !isRegistered else { return }
        
        // Register show/hide sidebar hotkey
        KeyboardShortcuts.onKeyDown(for: .showHideSidebar) { [weak self] in
            self?.handleShowHideSidebar()
        }
        
        // Register new chat hotkey
        KeyboardShortcuts.onKeyDown(for: .newChat) { [weak self] in
            self?.handleNewChat()
        }
        
        // Register focus input hotkey
        KeyboardShortcuts.onKeyDown(for: .focusInput) { [weak self] in
            self?.handleFocusInput()
        }
        
        // Register clear chat hotkey
        KeyboardShortcuts.onKeyDown(for: .clearChat) { [weak self] in
            self?.handleClearChat()
        }
        
        // Register export chat hotkey
        KeyboardShortcuts.onKeyDown(for: .exportChat) { [weak self] in
            self?.handleExportChat()
        }
        
        // Register toggle pin hotkey
        KeyboardShortcuts.onKeyDown(for: .togglePin) { [weak self] in
            self?.handleTogglePin()
        }
        
        // Register settings panel hotkey
        KeyboardShortcuts.onKeyDown(for: .settingsPanel) { [weak self] in
            self?.handleSettingsPanel()
        }
        
        isRegistered = true
    }
    
    // MARK: - Controller Integration
    
    func setSidebarController(_ controller: SidebarWindowController) {
        self.sidebarController = controller
    }
    
    // MARK: - Hotkey Handlers
    
    private func handleShowHideSidebar() {
        guard let controller = sidebarController else {
            // Fallback to shared instance
            SidebarWindowController.shared.toggleSidebar()
            return
        }
        
        controller.toggleSidebar()
    }
    
    private func handleNewChat() {
        // Post notification for new chat creation
        NotificationCenter.default.post(
            name: .hotkeyNewChat,
            object: self
        )
    }
    
    private func handleFocusInput() {
        // Post notification to focus input field
        NotificationCenter.default.post(
            name: .hotkeyFocusInput,
            object: self
        )
    }
    
    private func handleClearChat() {
        // Post notification to clear current chat
        NotificationCenter.default.post(
            name: .hotkeyClearChat,
            object: self
        )
    }
    
    private func handleExportChat() {
        // Post notification to export current chat
        NotificationCenter.default.post(
            name: .hotkeyExportChat,
            object: self
        )
    }
    
    private func handleTogglePin() {
        guard let controller = sidebarController else {
            // Fallback to shared instance
            let currentState = SidebarWindowController.shared.isSidebarPinned
            SidebarWindowController.shared.setSidebarPinned(!currentState)
            return
        }
        
        let currentState = controller.isSidebarPinned
        controller.setSidebarPinned(!currentState)
    }
    
    private func handleSettingsPanel() {
        // Post notification to show settings panel
        NotificationCenter.default.post(
            name: .hotkeySettingsPanel,
            object: self
        )
    }
    
    // MARK: - Utility Methods
    
    /// Disable all hotkeys (useful for certain app states)
    func disableHotkeys() {
        KeyboardShortcuts.disable(.showHideSidebar)
        KeyboardShortcuts.disable(.newChat)
        KeyboardShortcuts.disable(.focusInput)
        KeyboardShortcuts.disable(.clearChat)
        KeyboardShortcuts.disable(.exportChat)
        KeyboardShortcuts.disable(.togglePin)
        KeyboardShortcuts.disable(.settingsPanel)
    }
    
    /// Enable all hotkeys
    func enableHotkeys() {
        KeyboardShortcuts.enable(.showHideSidebar)
        KeyboardShortcuts.enable(.newChat)
        KeyboardShortcuts.enable(.focusInput)
        KeyboardShortcuts.enable(.clearChat)
        KeyboardShortcuts.enable(.exportChat)
        KeyboardShortcuts.enable(.togglePin)
        KeyboardShortcuts.enable(.settingsPanel)
    }
    
    /// Reset all hotkeys to defaults
    func resetToDefaults() {
        KeyboardShortcuts.reset(.showHideSidebar)
        KeyboardShortcuts.reset(.newChat)
        KeyboardShortcuts.reset(.focusInput)
        KeyboardShortcuts.reset(.clearChat)
        KeyboardShortcuts.reset(.exportChat)
        KeyboardShortcuts.reset(.togglePin)
        KeyboardShortcuts.reset(.settingsPanel)
    }
    
    /// Get current hotkey for a specific action
    func getHotkey(for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut? {
        return KeyboardShortcuts.getShortcut(for: name)
    }
    
    /// Set hotkey for a specific action
    func setHotkey(for name: KeyboardShortcuts.Name, shortcut: KeyboardShortcuts.Shortcut?) {
        KeyboardShortcuts.setShortcut(shortcut, for: name)
    }
    
    /// Check if hotkeys are currently enabled
    var areHotkeysEnabled: Bool {
        return KeyboardShortcuts.getShortcut(for: .showHideSidebar) != nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let hotkeyNewChat = Notification.Name("HotkeyNewChat")
    static let hotkeyFocusInput = Notification.Name("HotkeyFocusInput")
    static let hotkeyClearChat = Notification.Name("HotkeyClearChat")
    static let hotkeyExportChat = Notification.Name("HotkeyExportChat")
    static let hotkeySettingsPanel = Notification.Name("HotkeySettingsPanel")
}

// MARK: - HotkeyManager Extensions

extension HotkeyManager {
    
    /// Initialize hotkeys on app launch
    static func initializeOnLaunch() {
        _ = HotkeyManager.shared
    }
    
    /// Get user-friendly string representation of hotkey
    func getHotkeyString(for name: KeyboardShortcuts.Name) -> String {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else {
            return "None"
        }
        
        var components: [String] = []
        
        if shortcut.modifiers.contains(.command) {
            components.append("⌘")
        }
        if shortcut.modifiers.contains(.shift) {
            components.append("⇧")
        }
        if shortcut.modifiers.contains(.option) {
            components.append("⌥")
        }
        if shortcut.modifiers.contains(.control) {
            components.append("⌃")
        }
        
        // Add the key
        if let key = shortcut.key {
            components.append(key.stringValue)
        }
        
        return components.joined()
    }
    
    /// Check if accessibility permissions are granted
    func checkAccessibilityPermissions() -> Bool {
        // KeyboardShortcuts handles this internally
        return true
    }
    
    /// Request accessibility permissions
    func requestAccessibilityPermissions() {
        // KeyboardShortcuts handles this internally when needed
    }
}

// MARK: - Key Extensions

extension KeyboardShortcuts.Key {
    var stringValue: String {
        switch self {
        case .space: return "Space"
        case .return: return "Return"
        case .tab: return "Tab"
        case .delete: return "Delete"
        case .escape: return "Escape"
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        case .g: return "G"
        case .h: return "H"
        case .i: return "I"
        case .j: return "J"
        case .k: return "K"
        case .l: return "L"
        case .m: return "M"
        case .n: return "N"
        case .o: return "O"
        case .p: return "P"
        case .q: return "Q"
        case .r: return "R"
        case .s: return "S"
        case .t: return "T"
        case .u: return "U"
        case .v: return "V"
        case .w: return "W"
        case .x: return "X"
        case .y: return "Y"
        case .z: return "Z"
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .comma: return ","
        case .period: return "."
        case .slash: return "/"
        case .semicolon: return ";"
        case .quote: return "'"
        case .leftBracket: return "["
        case .rightBracket: return "]"
        case .backslash: return "\\"
        case .minus: return "-"
        case .equal: return "="
        case .backtick: return "`"
        default: return rawValue.description
        }
    }
}