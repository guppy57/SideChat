import AppKit
import SwiftUI
import Defaults

// MARK: - Sidebar Window Controller

/// Manages the sidebar window lifecycle and coordinates with the app's state
class SidebarWindowController: NSWindowController {
    
    // MARK: - Properties
    
    private var sidebarWindow: SidebarWindow!
    private var isInitialized = false
    
    // Settings observers
    @Default(.sidebarEdgePosition) private var edgePosition
    @Default(.sidebarWidth) private var sidebarWidth
    @Default(.sidebarHeight) private var sidebarHeight
    
    // MARK: - Initialization
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupSidebarWindow()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSidebarWindow()
    }
    
    convenience init() {
        self.init(window: nil)
    }
    
    // MARK: - Window Setup
    
    private func setupSidebarWindow() {
        guard !isInitialized else { return }
        
        let edgePos: SidebarWindow.EdgePosition = edgePosition == "left" ? .left : .right
        sidebarWindow = SidebarWindow(edgePosition: edgePos)
        sidebarWindow.sidebarDelegate = self
        
        self.window = sidebarWindow
        
        // Setup settings observers
        setupSettingsObservers()
        
        // Monitor screen changes
        setupScreenMonitoring()
        
        isInitialized = true
    }
    
    // MARK: - Settings Observers
    
    private func setupSettingsObservers() {
        // Observe edge position changes
        Defaults.observe(.sidebarEdgePosition) { [weak self] change in
            guard let self = self else { return }
            let newPosition: SidebarWindow.EdgePosition = change.newValue == "left" ? .left : .right
            self.sidebarWindow.setEdgePosition(newPosition)
        }
        
        // Observe width changes
        Defaults.observe(.sidebarWidth) { [weak self] change in
            guard let self = self else { return }
            self.updateWindowSize()
        }
        
        // Observe height changes
        Defaults.observe(.sidebarHeight) { [weak self] change in
            guard let self = self else { return }
            self.updateWindowSize()
        }
    }
    
    private func updateWindowSize() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let newWidth = CGFloat(sidebarWidth)
        let newHeight = sidebarHeight > 0 ? CGFloat(sidebarHeight) : screenFrame.height - 100
        
        let currentFrame = sidebarWindow.frame
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y,
            width: newWidth,
            height: newHeight
        )
        
        sidebarWindow.setFrame(newFrame, display: true, animate: true)
    }
    
    // MARK: - Screen Monitoring
    
    private func setupScreenMonitoring() {
        // Monitor for screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenConfigurationDidChange() {
        sidebarWindow.updateForScreenChange()
    }
    
    // MARK: - Public Interface
    
    func showSidebar() {
        sidebarWindow.showAnimated()
    }
    
    func hideSidebar() {
        sidebarWindow.hideAnimated()
    }
    
    func toggleSidebar() {
        if sidebarWindow.isVisible {
            hideSidebar()
        } else {
            showSidebar()
        }
    }
    
    func setSidebarPinned(_ pinned: Bool) {
        sidebarWindow.setPinned(pinned)
    }
    
    var isSidebarVisible: Bool {
        return sidebarWindow.isVisible
    }
    
    var isSidebarPinned: Bool {
        return sidebarWindow.pinnedState
    }
    
    // MARK: - Content Management
    
    func setContent<Content: View>(_ content: Content) {
        sidebarWindow.setupWithSwiftUIContent(content)
    }
    
    // MARK: - Cleanup
    
    /// Graceful cleanup for app shutdown
    func shutdown() async {
        // Hide sidebar with animation if visible
        if isSidebarVisible {
            hideSidebar()
            
            // Give animation time to complete
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        // Remove observers
        cleanup()
    }
    
    /// Immediate cleanup without animations
    func cleanup() {
        NotificationCenter.default.removeObserver(self)
        
        // Cancel any ongoing Defaults observations
        // Note: Defaults handles this automatically, but we're being explicit
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - SidebarWindowDelegate Implementation

extension SidebarWindowController: SidebarWindowDelegate {
    
    func sidebarWindowWillShow(_ window: SidebarWindow) {
        // Post notification for other components
        NotificationCenter.default.post(
            name: .sidebarWillShow,
            object: self
        )
    }
    
    func sidebarWindowDidShow(_ window: SidebarWindow) {
        // Post notification for other components
        NotificationCenter.default.post(
            name: .sidebarDidShow,
            object: self
        )
    }
    
    func sidebarWindowWillHide(_ window: SidebarWindow) {
        // Post notification for other components
        NotificationCenter.default.post(
            name: .sidebarWillHide,
            object: self
        )
    }
    
    func sidebarWindowDidHide(_ window: SidebarWindow) {
        // Post notification for other components
        NotificationCenter.default.post(
            name: .sidebarDidHide,
            object: self
        )
    }
    
    func sidebarWindowDidChangePin(_ window: SidebarWindow, isPinned: Bool) {
        // Update defaults
        Defaults[.sidebarIsPinned] = isPinned
        
        // Post notification for other components
        NotificationCenter.default.post(
            name: .sidebarDidChangePin,
            object: self,
            userInfo: ["isPinned": isPinned]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let sidebarWillShow = Notification.Name("SidebarWillShow")
    static let sidebarDidShow = Notification.Name("SidebarDidShow")
    static let sidebarWillHide = Notification.Name("SidebarWillHide")
    static let sidebarDidHide = Notification.Name("SidebarDidHide")
    static let sidebarDidChangePin = Notification.Name("SidebarDidChangePin")
}

// MARK: - SidebarWindowController + Singleton

extension SidebarWindowController {
    
    static let shared = SidebarWindowController()
    
    /// Convenience method to show sidebar from anywhere in the app
    static func show() {
        shared.showSidebar()
    }
    
    /// Convenience method to hide sidebar from anywhere in the app
    static func hide() {
        shared.hideSidebar()
    }
    
    /// Convenience method to toggle sidebar from anywhere in the app
    static func toggle() {
        shared.toggleSidebar()
    }
}