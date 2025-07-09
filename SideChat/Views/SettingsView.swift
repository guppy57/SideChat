import SwiftUI
import Defaults
import LaunchAtLogin

// MARK: - Settings View

/// Main settings window with tabbed interface
struct SettingsView: View {
    
    // MARK: - Properties
    
    @State private var selectedTab = SettingsTab.general
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)
            
            APIKeySettingsView()
                .tabItem {
                    Label("API Keys", systemImage: "key.fill")
                }
                .tag(SettingsTab.apiKeys)
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush.fill")
                }
                .tag(SettingsTab.appearance)
            
            KeyboardSettingsView()
                .tabItem {
                    Label("Keyboard", systemImage: "keyboard.fill")
                }
                .tag(SettingsTab.keyboard)
            
            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "lock.fill")
                }
                .tag(SettingsTab.privacy)
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver.fill")
                }
                .tag(SettingsTab.advanced)
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case apiKeys
    case appearance
    case keyboard
    case privacy
    case advanced
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return "General"
        case .apiKeys: return "API Keys"
        case .appearance: return "Appearance"
        case .keyboard: return "Keyboard"
        case .privacy: return "Privacy"
        case .advanced: return "Advanced"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .apiKeys: return "key.fill"
        case .appearance: return "paintbrush.fill"
        case .keyboard: return "keyboard.fill"
        case .privacy: return "lock.fill"
        case .advanced: return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - General Settings View

struct GeneralSettingsView: View {
    @Default(.defaultLLMProvider) private var defaultProvider
    @Default(.sidebarEdge) private var sidebarEdge
    @Default(.autoHideSidebar) private var autoHideSidebar
    @Default(.enableAnimations) private var enableAnimations
    
    var body: some View {
        Form {
            Section {
                LaunchAtLogin.Toggle()
                    .padding(.vertical, 4)
            }
            
            Section("Default Provider") {
                Picker("LLM Provider", selection: $defaultProvider) {
                    ForEach(LLMProvider.allCases, id: \.self) { provider in
                        HStack {
                            Image(systemName: provider.icon)
                            Text(provider.displayName)
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
            }
            
            Section("Sidebar") {
                Picker("Position", selection: $sidebarEdge) {
                    Text("Left").tag(SidebarEdge.left)
                    Text("Right").tag(SidebarEdge.right)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
                
                Toggle("Auto-hide when clicking outside", isOn: $autoHideSidebar)
                Toggle("Enable animations", isOn: $enableAnimations)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Settings View

struct AppearanceSettingsView: View {
    @Default(.colorTheme) private var colorTheme
    @Default(.fontSize) private var fontSize
    @Default(.fontFamily) private var fontFamily
    @Default(.sidebarTransparency) private var transparency
    @Default(.sidebarBlurIntensity) private var blurIntensity
    @Default(.appearanceMode) private var appearanceMode
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Color Theme", selection: $colorTheme) {
                    ForEach(ColorTheme.allCases, id: \.self) { theme in
                        HStack {
                            Circle()
                                .fill(theme.color)
                                .frame(width: 12, height: 12)
                            Text(theme.displayName)
                        }
                        .tag(theme)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
                
                Picker("Appearance", selection: $appearanceMode) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 250)
            }
            
            Section("Typography") {
                HStack {
                    Text("Font Size")
                    Slider(value: $fontSize, in: 10...20, step: 1)
                        .frame(width: 200)
                    Text("\(Int(fontSize))pt")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                
                Picker("Font Family", selection: $fontFamily) {
                    Text("SF Pro Text").tag("SF Pro Text")
                    Text("SF Mono").tag("SF Mono")
                    Text("New York").tag("New York")
                    Text("Helvetica Neue").tag("Helvetica Neue")
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
            }
            
            Section("Window") {
                HStack {
                    Text("Transparency")
                    Slider(value: $transparency, in: 0.1...1.0)
                        .frame(width: 200)
                    Text("\(Int(transparency * 100))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Blur Intensity")
                    Slider(value: $blurIntensity, in: 0.0...1.0)
                        .frame(width: 200)
                    Text("\(Int(blurIntensity * 100))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Keyboard Settings View

struct KeyboardSettingsView: View {
    @Default(.showHideHotkey) private var showHideHotkey
    @Default(.newChatHotkey) private var newChatHotkey
    
    var body: some View {
        Form {
            Section("Global Shortcuts") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Configure keyboard shortcuts for quick access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // TODO: Integrate KeyboardShortcuts.Recorder when implementing
                    HStack {
                        Text("Show/Hide Sidebar")
                            .frame(width: 150, alignment: .leading)
                        Text(showHideHotkey)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("New Chat")
                            .frame(width: 150, alignment: .leading)
                        Text(newChatHotkey)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            
            Section {
                Text("Note: Click on a shortcut to change it")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Privacy Settings View

struct PrivacySettingsView: View {
    @Default(.storeConversationHistory) private var storeHistory
    @Default(.enableDataEncryption) private var enableEncryption
    @Default(.autoDeleteOldChats) private var autoDelete
    @Default(.autoDeleteDays) private var deleteDays
    
    var body: some View {
        Form {
            Section("Data Storage") {
                Toggle("Store conversation history", isOn: $storeHistory)
                Toggle("Enable database encryption", isOn: $enableEncryption)
                    .disabled(!storeHistory)
            }
            
            Section("Data Retention") {
                Toggle("Auto-delete old chats", isOn: $autoDelete)
                
                if autoDelete {
                    Picker("Delete after", selection: $deleteDays) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("180 days").tag(180)
                        Text("365 days").tag(365)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 150)
                }
            }
            
            Section {
                Button("Clear All Chat History...") {
                    // TODO: Implement clear history with confirmation
                }
                .foregroundColor(.red)
                
                Text("This action cannot be undone")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Advanced Settings View

struct AdvancedSettingsView: View {
    @Default(.enableDebugMode) private var debugMode
    @Default(.enableBetaFeatures) private var betaFeatures
    @Default(.requestTimeout) private var requestTimeout
    @Default(.maxChatHistory) private var maxChatHistory
    @Default(.enableStreamingResponses) private var streamingResponses
    
    var body: some View {
        Form {
            Section("Developer Options") {
                Toggle("Enable debug mode", isOn: $debugMode)
                Toggle("Enable beta features", isOn: $betaFeatures)
            }
            
            Section("Performance") {
                HStack {
                    Text("Request timeout")
                    Slider(value: $requestTimeout, in: 30...600, step: 30)
                        .frame(width: 200)
                    Text("\(Int(requestTimeout))s")
                        .monospacedDigit()
                        .frame(width: 50)
                }
                
                Picker("Max chat history", selection: $maxChatHistory) {
                    Text("100 chats").tag(100)
                    Text("500 chats").tag(500)
                    Text("1000 chats").tag(1000)
                    Text("5000 chats").tag(5000)
                    Text("Unlimited").tag(Int.max)
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 150)
                
                Toggle("Enable streaming responses", isOn: $streamingResponses)
            }
            
            Section {
                Button("Reset All Settings to Defaults...") {
                    // TODO: Implement reset with confirmation
                }
                .foregroundColor(.red)
                
                Button("Export Settings...") {
                    // TODO: Implement settings export
                }
                
                Button("Import Settings...") {
                    // TODO: Implement settings import
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - LLMProvider Extension

extension LLMProvider {
    var icon: String {
        switch self {
        case .openai: return "brain"
        case .anthropic: return "ant.circle"
        case .google: return "sparkle"
        case .local: return "desktopcomputer"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif