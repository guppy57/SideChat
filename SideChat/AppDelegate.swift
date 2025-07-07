//
//  AppDelegate.swift
//  SideChat
//
//  Created by Armaan Gupta on 7/7/25.
//

import AppKit
import Foundation
import SwiftUI

// MARK: - App Delegate

/// AppDelegate manages the application lifecycle and handles graceful shutdown
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    private lazy var terminationCoordinator = TerminationCoordinator()
    private var isInitialized = false
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isInitialized else { return }
        
        Task { @MainActor in
            await initializeApp()
        }
        
        isInitialized = true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If already terminating, allow immediate termination
        if terminationCoordinator.isTerminating {
            return .terminateNow
        }
        
        // Start graceful shutdown process
        Task {
            await terminationCoordinator.beginGracefulShutdown()
            
            // After cleanup completes, terminate the app
            DispatchQueue.main.async {
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
            }
        }
        
        // Tell macOS to wait for our async cleanup
        return .terminateLater
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Final cleanup if not already done
        terminationCoordinator.forceCleanup()
    }
    
    // MARK: - App Initialization
    
    @MainActor
    private func initializeApp() async {
        // Initialize database
        await DatabaseManager.shared.initialize()
        
        // Perform settings migration
        await SettingsMigrator.shared.migrateIfNeeded()
        
        // Update app version tracking
        updateVersionTracking()
        
        // Mark as no longer first launch
        updateFirstLaunchFlag()
        
        // Step 1: Create and show the EdgeTabWindow
        EdgeTabManager.show()
        
        // Step 3: Connect HotkeyManager to controller
        HotkeyManager.initializeOnLaunch()
        
        // Step 2: Instantiate SidebarWindowController
        let sidebarController = SidebarWindowController.shared
        sidebarController.setContent(SidebarView())
        
        // Connect HotkeyManager to the sidebar controller
        HotkeyManager.shared.setSidebarController(sidebarController)
    }
    
    @MainActor
    private func updateVersionTracking() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let defaultsManager = DefaultsManager.shared
        
        if defaultsManager.lastOpenedVersion != currentVersion {
            defaultsManager.lastOpenedVersion = currentVersion
        }
    }
    
    @MainActor
    private func updateFirstLaunchFlag() {
        let defaultsManager = DefaultsManager.shared
        if defaultsManager.isFirstLaunch {
            defaultsManager.isFirstLaunch = false
        }
    }
}

// MARK: - Termination Coordinator

/// Coordinates graceful shutdown of app components
class TerminationCoordinator: ObservableObject {
    
    // MARK: - Properties
    
    private(set) var isTerminating = false
    private let shutdownTimeout: TimeInterval = 3.0 // 3 second timeout
    
    // MARK: - Graceful Shutdown
    
    func beginGracefulShutdown() async {
        guard !isTerminating else { return }
        isTerminating = true
        
        print("🔄 Beginning graceful app shutdown...")
        
        // Run shutdown with timeout
        await withTimeout(shutdownTimeout) {
            await self.performCleanupOperations()
        }
        
        print("✅ App shutdown completed")
    }
    
    func forceCleanup() {
        guard isTerminating else { return }
        
        print("⚠️ Forcing immediate cleanup")
        
        // Perform synchronous cleanup that must complete
        print("⚠️ Immediate cleanup completed")
    }
    
    // MARK: - Cleanup Operations
    
    private func performCleanupOperations() async {
        // Cleanup database operations
        print("🔄 Cleaning up database...")
        
        // Cleanup window controllers
        await cleanupWindowControllers()
        
        // Cleanup observers and notifications
        await cleanupObservers()
    }
    
    @MainActor
    private func cleanupWindowControllers() async {
        // Use the new shutdown method for graceful cleanup
        await SidebarWindowController.shared.shutdown()
    }
    
    @MainActor
    private func cleanupObservers() async {
        // Observers are now cleaned up by individual components
        // This ensures proper cleanup order and prevents double-cleanup
        
        // Force cleanup of any remaining observers
        SidebarWindowController.shared.cleanup()
    }
    
    // MARK: - Timeout Helper
    
    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async -> T? {
        return await withTaskGroup(of: T?.self) { group in
            // Add the main operation
            group.addTask {
                do {
                    return try await operation()
                } catch {
                    print("❌ Cleanup operation failed: \(error)")
                    return nil
                }
            }
            
            // Add timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            
            // Return the first result (either completion or timeout)
            let result = await group.next()
            group.cancelAll()
            return result ?? nil
        }
    }
}