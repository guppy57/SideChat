import AppKit
import SwiftUI
import Defaults

// MARK: - Custom Sidebar Window

/// Custom NSWindow subclass designed for the SideChat sidebar
/// Features: borderless, non-activating panel that appears over other apps
class SidebarWindow: NSWindow {
    
    // MARK: - Properties
    
    private var isSlideAnimationInProgress = false
    private var edgePosition: EdgePosition = .right
    internal var isPinned = false
    weak var sidebarDelegate: SidebarWindowDelegate?
    
    // Mouse edge detection
    private var edgeDetectionMonitor: Any?
    private var isEdgeDetectionEnabled = true
    private let edgeDetectionThreshold: CGFloat = 5.0 // pixels from edge to trigger
    
    // Auto-hide monitoring
    private var autoHideMonitor: Any?
    private var isAutoHideEnabled = true
    
    enum EdgePosition {
        case left
        case right
    }
    
    // MARK: - Initialization
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: backingStoreType,
            defer: flag
        )
        
        setupWindow()
    }
    
    convenience init(edgePosition: EdgePosition = .right) {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let windowWidth: CGFloat = CGFloat(Defaults[.sidebarWidth])
        let windowHeight: CGFloat = screenFrame.height - 100 // Leave some margin from top/bottom
        
        let xPosition: CGFloat
        switch edgePosition {
        case .left:
            xPosition = -windowWidth // Start hidden off-screen
        case .right:
            xPosition = screenFrame.width // Start hidden off-screen
        }
        
        let contentRect = NSRect(
            x: xPosition,
            y: 50, // 50px from bottom
            width: windowWidth,
            height: windowHeight
        )
        
        self.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.edgePosition = edgePosition
    }
    
    // MARK: - Window Setup
    
    private func setupWindow() {
        // Window behavior
        self.level = .floating // Appears above other windows
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false // No shadow for transparent window
        self.hidesOnDeactivate = false
        
        // Prevent window from appearing in mission control, dock, etc.
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]
        
        // Configure for non-activating behavior
        // Note: canBecomeMain and canBecomeKey are implemented as overrides below
        
        // Set window to be movable by background
        self.isMovableByWindowBackground = false
        
        // Configure resize behavior
        self.minSize = NSSize(width: 300, height: 400)
        self.maxSize = NSSize(width: 600, height: NSScreen.main?.frame.height ?? 900)
        
        // Setup auto-hide behavior
        setupAutoHide()
        
        // Setup mouse edge detection
        setupMouseEdgeDetection()
    }
    
    // MARK: - Auto-Hide Behavior
    
    private func setupAutoHide() {
        guard isAutoHideEnabled else { return }
        
        // Remove existing monitor if any
        if let monitor = autoHideMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Set up global mouse click monitoring for auto-hide
        autoHideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleAutoHideEvent(event)
        }
    }
    
    private func handleAutoHideEvent(_ event: NSEvent) {
        guard isAutoHideEnabled && !isPinned && isVisible else { return }
        
        let clickLocation = event.locationInWindow
        let windowFrame = self.frame
        
        // Convert click location to screen coordinates if needed
        let screenClickLocation = NSEvent.mouseLocation
        
        // Check if click is outside the sidebar window
        if !windowFrame.contains(screenClickLocation) {
            hideAnimated()
        }
    }
    
    // MARK: - Mouse Edge Detection
    
    private func setupMouseEdgeDetection() {
        guard isEdgeDetectionEnabled else { return }
        
        // Remove existing monitor if any
        if let monitor = edgeDetectionMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Set up global mouse movement monitoring
        edgeDetectionMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        guard isEdgeDetectionEnabled && !isVisible && !isPinned else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        
        // Get the screen containing the mouse
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else { return }
        
        let screenFrame = screen.frame
        let isAtEdge: Bool
        
        switch edgePosition {
        case .left:
            // Check if mouse is at the left edge
            isAtEdge = mouseLocation.x <= screenFrame.minX + edgeDetectionThreshold
        case .right:
            // Check if mouse is at the right edge
            isAtEdge = mouseLocation.x >= screenFrame.maxX - edgeDetectionThreshold
        }
        
        if isAtEdge {
            showAnimated()
        }
    }
    
    // MARK: - Edge Detection Control
    
    func enableEdgeDetection() {
        guard !isEdgeDetectionEnabled else { return }
        isEdgeDetectionEnabled = true
        setupMouseEdgeDetection()
    }
    
    func disableEdgeDetection() {
        guard isEdgeDetectionEnabled else { return }
        isEdgeDetectionEnabled = false
        
        if let monitor = edgeDetectionMonitor {
            NSEvent.removeMonitor(monitor)
            edgeDetectionMonitor = nil
        }
    }
    
    var isEdgeDetectionActive: Bool {
        return isEdgeDetectionEnabled && edgeDetectionMonitor != nil
    }
    
    // MARK: - Auto-Hide Control
    
    func enableAutoHide() {
        guard !isAutoHideEnabled else { return }
        isAutoHideEnabled = true
        setupAutoHide()
    }
    
    func disableAutoHide() {
        guard isAutoHideEnabled else { return }
        isAutoHideEnabled = false
        
        if let monitor = autoHideMonitor {
            NSEvent.removeMonitor(monitor)
            autoHideMonitor = nil
        }
    }
    
    var isAutoHideActive: Bool {
        return isAutoHideEnabled && autoHideMonitor != nil
    }
    
    // MARK: - Show/Hide Animation
    
    func showAnimated() {
        guard !isSlideAnimationInProgress else { return }
        
        isSlideAnimationInProgress = true
        
        let screenFrame = NSScreen.main?.frame ?? frame
        let targetX: CGFloat
        
        switch edgePosition {
        case .left:
            targetX = 0
        case .right:
            targetX = screenFrame.width - frame.width
        }
        
        let targetFrame = NSRect(
            x: targetX,
            y: frame.origin.y,
            width: frame.width,
            height: frame.height
        )
        
        // Make window visible
        self.orderFront(nil)
        
        // Animate to target position with optimized timing for < 100ms
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08 // 80ms - under 100ms requirement
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            self.setFrame(targetFrame, display: true, animate: true)
        }) {
            self.isSlideAnimationInProgress = false
        }
    }
    
    func hideAnimated() {
        guard !isSlideAnimationInProgress && !isPinned else { return }
        
        isSlideAnimationInProgress = true
        
        let screenFrame = NSScreen.main?.frame ?? frame
        let targetX: CGFloat
        
        switch edgePosition {
        case .left:
            targetX = -frame.width
        case .right:
            targetX = screenFrame.width
        }
        
        let targetFrame = NSRect(
            x: targetX,
            y: frame.origin.y,
            width: frame.width,
            height: frame.height
        )
        
        // Animate to hidden position with optimized timing for < 100ms
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.06 // 60ms - faster hide animation
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            
            self.setFrame(targetFrame, display: true, animate: true)
        }) {
            self.orderOut(nil)
            self.isSlideAnimationInProgress = false
        }
    }
    
    // MARK: - Pin/Unpin Functionality
    
    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        
        // Update window behavior based on pinned state
        if pinned {
            self.level = .normal
            self.collectionBehavior.insert(.participatesInCycle)
        } else {
            self.level = .floating
            self.collectionBehavior.remove(.participatesInCycle)
        }
    }
    
    var pinnedState: Bool {
        return isPinned
    }
    
    // MARK: - Edge Position
    
    func setEdgePosition(_ position: EdgePosition) {
        guard position != edgePosition else { return }
        
        edgePosition = position
        
        // Restart edge detection for new position
        if isEdgeDetectionEnabled {
            setupMouseEdgeDetection()
        }
        
        // If window is currently visible, hide and re-show from new edge
        if isVisible {
            hideAnimated()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showAnimated()
            }
        }
    }
    
    // MARK: - Screen Management
    
    func updateForScreenChange() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let windowHeight = screenFrame.height - 100
        
        // Update window size for new screen
        let newFrame = NSRect(
            x: frame.origin.x,
            y: 50,
            width: frame.width,
            height: windowHeight
        )
        
        setFrame(newFrame, display: true, animate: false)
        
        // If visible, reposition for new screen
        if isVisible {
            let targetX: CGFloat
            switch edgePosition {
            case .left:
                targetX = 0
            case .right:
                targetX = screenFrame.width - frame.width
            }
            
            let targetFrame = NSRect(
                x: targetX,
                y: frame.origin.y,
                width: frame.width,
                height: frame.height
            )
            
            setFrame(targetFrame, display: true, animate: true)
        }
    }
    
    // MARK: - Window Delegate Methods
    
    override var canBecomeKey: Bool {
        true
    }
    
    override var canBecomeMain: Bool {
        false
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupWindow()
    }
    
    deinit {
        // Clean up event monitors
        if let monitor = edgeDetectionMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = autoHideMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
}

// MARK: - SidebarWindow + SwiftUI Integration

extension SidebarWindow {
    
    /// Sets up the window with a SwiftUI content view and transparent background
    func setupWithSwiftUIContent<Content: View>(_ content: Content) {
        // Create a transparent container view
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Set up the hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Make the hosting view transparent
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Set the container as the window's content view
        self.contentView = containerView
        
        // Add the hosting view to the container
        containerView.addSubview(hostingView)
        
        // Set up constraints to fill the window
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    // Note: Blur effects are now handled at the individual UI element level,
    // not at the window level. These methods are kept for backward compatibility
    // but have no effect on the transparent window.
    
    /// Deprecated: Blur effects are now handled at the UI element level
    @available(*, deprecated, message: "Use BlurredBackground view modifier on individual elements instead")
    func updateBlurEffect(material: NSVisualEffectView.Material) {
        // No-op: Window is now transparent
    }
    
    /// Deprecated: Blur effects are now handled at the UI element level
    @available(*, deprecated, message: "Use BlurredBackground view modifier on individual elements instead")
    func updateBlurIntensity(_ intensity: Double) {
        // No-op: Window is now transparent
    }
    
    /// Deprecated: Blur effects are now handled at the UI element level
    @available(*, deprecated, message: "Use BlurredBackground view modifier on individual elements instead")
    func updateBlurForTheme(isDark: Bool) {
        // No-op: Window is now transparent
    }
}

// MARK: - SidebarWindowDelegate Protocol

protocol SidebarWindowDelegate: AnyObject {
    func sidebarWindowWillShow(_ window: SidebarWindow)
    func sidebarWindowDidShow(_ window: SidebarWindow)
    func sidebarWindowWillHide(_ window: SidebarWindow)
    func sidebarWindowDidHide(_ window: SidebarWindow)
    func sidebarWindowDidChangePin(_ window: SidebarWindow, isPinned: Bool)
}

// MARK: - SidebarWindow + Delegate Support

extension SidebarWindow {
    
    private func notifyWillShow() {
        sidebarDelegate?.sidebarWindowWillShow(self)
    }
    
    private func notifyDidShow() {
        sidebarDelegate?.sidebarWindowDidShow(self)
    }
    
    private func notifyWillHide() {
        sidebarDelegate?.sidebarWindowWillHide(self)
    }
    
    private func notifyDidHide() {
        sidebarDelegate?.sidebarWindowDidHide(self)
    }
    
    private func notifyDidChangePin() {
        sidebarDelegate?.sidebarWindowDidChangePin(self, isPinned: isPinned)
    }
}