//
//  SideChatApp.swift
//  SideChat
//
//  Created by Armaan Gupta on 7/7/25.
//

import SwiftUI
import LaunchAtLogin
import Defaults
import SQLite

@main
struct SideChatApp: App {
    @StateObject private var defaultsManager = DefaultsManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Basic setup only - async initialization moved to AppDelegate
        // This prevents unstructured Tasks during app initialization
        setupBasicConfiguration()
    }
    
    // MARK: - Basic Configuration
    
    private func setupBasicConfiguration() {
        // Configure any synchronous app settings here
        // All async initialization is handled by AppDelegate
        
        // Configure SQLite's date formatter to use a consistent format
        configureSQLiteDateFormatter()
        
        #if DEBUG
        print("🚀 SideChat starting up...")
        #endif
    }
    
    private func configureSQLiteDateFormatter() {
        // Set up the global date formatter for SQLite.swift
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(defaultsManager)
        }
        
        #if DEBUG
        Settings {
            DebugSettingsView()
                .environmentObject(defaultsManager)
        }
        #endif
    }
}

// MARK: - Debug Settings View for Development

#if DEBUG
struct DebugSettingsView: SwiftUI.View {
    @EnvironmentObject var defaults: DefaultsManager
    
    var body: some SwiftUI.View {
        Form {
            Section("Launch at Login") {
                LaunchAtLogin.Toggle()
            }
            
            Section("Debug Info") {
                LabeledContent("First Launch", value: defaults.isFirstLaunch ? "Yes" : "No")
                LabeledContent("Onboarding Complete", value: defaults.hasCompletedOnboarding ? "Yes" : "No")
                LabeledContent("Last Version", value: defaults.lastOpenedVersion)
                LabeledContent("Debug Mode", value: defaults.enableDebugMode ? "On" : "Off")
                LabeledContent("Schema Version", value: "\(SettingsMigrator.shared.getCurrentSchemaVersion())")
                LabeledContent("Needs Migration", value: SettingsMigrator.shared.needsMigration() ? "Yes" : "No")
            }
            
            Section("Actions") {
                Button("Reset All Settings") {
                    defaults.resetToDefaults()
                }
                .foregroundColor(.red)
                
                Button("Force Migration") {
                    Task {
                        await SettingsMigrator.shared.migrateIfNeeded()
                    }
                }
                .foregroundColor(.blue)
            }
        }
        .frame(width: 400, height: 300)
        .navigationTitle("Debug Settings")
    }
}
#endif
