import SwiftUI
import AppKit
import Defaults

// MARK: - Edge Tab View

/// Always-visible edge tab that responds to clicks to show the sidebar
struct EdgeTabView: View {
    
    // MARK: - Properties
    
    @Default(.sidebarEdgePosition) private var edgePosition
    @Default(.sidebarTransparency) private var transparency
    @Default(.colorTheme) private var colorTheme
    @State private var isHovered = false
    
    // Callback for when tab is clicked
    let onTabClicked: () -> Void
    
    // MARK: - Constants
    
    private let tabWidth: CGFloat = 12
    private let tabHeight: CGFloat = 80
    private let cornerRadius: CGFloat = 4
    
    // MARK: - Body
    
    var body: some View {
        Rectangle()
            .fill(tabAccentColor)
            .frame(width: tabWidth, height: tabHeight)
            .cornerRadius(cornerRadius)
            .opacity(isHovered ? 1.0 : 0.85)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                onTabClicked()
            }
            .help("Click to show SideChat")
    }
    
    // MARK: - Computed Properties
    
    private var tabBackgroundColor: Color {
        Color.primary.opacity(0.1)
    }
    
    private var tabAccentColor: Color {
        switch colorTheme {
        case .blue:
            return .blue
        case .green:
            return .green
        case .purple:
            return .purple
        case .orange:
            return .orange
        case .gray:
            return .gray
        }
    }
}

// MARK: - Edge Tab Window

/// NSWindow subclass that hosts the always-visible edge tab
class EdgeTabWindow: NSWindow {
    
    // MARK: - Properties
    
    private var edgePosition: SidebarWindow.EdgePosition = .right
    private let tabHeight: CGFloat = 80
    private let tabWidth: CGFloat = 12
    
    // Callback for when tab is clicked
    var onTabClicked: (() -> Void)?
    
    // MARK: - Initialization
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: backingStoreType,
            defer: flag
        )
        
        setupWindow()
    }
    
    convenience init(edgePosition: SidebarWindow.EdgePosition = .right) {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let tabWidth: CGFloat = 12
        let tabHeight: CGFloat = 80
        
        let xPosition: CGFloat
        switch edgePosition {
        case .left:
            xPosition = 0
        case .right:
            xPosition = screenFrame.width - tabWidth
        }
        
        let yPosition = (screenFrame.height - tabHeight) / 2
        
        let contentRect = NSRect(
            x: xPosition,
            y: yPosition,
            width: tabWidth,
            height: tabHeight
        )
        
        self.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.edgePosition = edgePosition
    }
    
    // MARK: - Window Setup
    
    private func setupWindow() {
        // Window behavior
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.hidesOnDeactivate = false
        
        // Prevent window from appearing in mission control, dock, etc.
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        
        // Set window to be non-activating
        self.isMovableByWindowBackground = false
        
        // Setup content view
        setupContentView()
    }
    
    private func setupContentView() {
        let tabView = EdgeTabView {
            self.onTabClicked?()
        }
        
        let hostingView = NSHostingView(rootView: tabView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        self.contentView = hostingView
        
        // Make sure the hosting view fills the window
        if let contentView = self.contentView {
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
    }
    
    // MARK: - Position Management
    
    func updatePosition(for edgePosition: SidebarWindow.EdgePosition) {
        guard let screen = NSScreen.main else { return }
        
        self.edgePosition = edgePosition
        let screenFrame = screen.frame
        
        let xPosition: CGFloat
        switch edgePosition {
        case .left:
            xPosition = 0
        case .right:
            xPosition = screenFrame.width - tabWidth
        }
        
        let yPosition = (screenFrame.height - tabHeight) / 2
        
        let newFrame = NSRect(
            x: xPosition,
            y: yPosition,
            width: tabWidth,
            height: tabHeight
        )
        
        self.setFrame(newFrame, display: true, animate: true)
    }
    
    func updateForScreenChange() {
        updatePosition(for: edgePosition)
    }
    
    // MARK: - Show/Hide
    
    func show() {
        self.orderFront(nil)
    }
    
    func hide() {
        self.orderOut(nil)
    }
    
    // MARK: - Window Delegate Methods
    
    override var canBecomeKey: Bool {
        false
    }
    
    override var canBecomeMain: Bool {
        false
    }
}

// MARK: - Edge Tab Manager

/// Manages the edge tab window lifecycle and coordinates with sidebar
class EdgeTabManager: ObservableObject {
    
    // MARK: - Properties
    
    private var edgeTabWindow: EdgeTabWindow?
    private var isVisible = false
    
    // Settings observers
    @Default(.sidebarEdgePosition) private var edgePosition
    
    // MARK: - Initialization
    
    init() {
        setupEdgeTab()
        setupSettingsObservers()
        setupScreenMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupEdgeTab() {
        let edgePos: SidebarWindow.EdgePosition = edgePosition == "left" ? .left : .right
        edgeTabWindow = EdgeTabWindow(edgePosition: edgePos)
        
        edgeTabWindow?.onTabClicked = { [weak self] in
            self?.handleTabClicked()
        }
        
        // Show the tab window
        edgeTabWindow?.show()
        isVisible = true
    }
    
    private func setupSettingsObservers() {
        // Observe edge position changes
        Defaults.observe(.sidebarEdgePosition) { [weak self] change in
            guard let self = self else { return }
            let newPosition: SidebarWindow.EdgePosition = change.newValue == "left" ? .left : .right
            self.edgeTabWindow?.updatePosition(for: newPosition)
        }
    }
    
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
        edgeTabWindow?.updateForScreenChange()
    }
    
    // MARK: - Tab Management
    
    func showTab() {
        guard !isVisible else { return }
        edgeTabWindow?.show()
        isVisible = true
    }
    
    func hideTab() {
        guard isVisible else { return }
        edgeTabWindow?.hide()
        isVisible = false
    }
    
    func toggleTab() {
        if isVisible {
            hideTab()
        } else {
            showTab()
        }
    }
    
    // MARK: - Event Handling
    
    private func handleTabClicked() {
        // Post notification to show sidebar
        NotificationCenter.default.post(
            name: .edgeTabClicked,
            object: self
        )
        
        // Or directly trigger sidebar if we have reference
        SidebarWindowController.shared.showSidebar()
    }
    
    // MARK: - Cleanup
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        edgeTabWindow?.close()
    }
}

// MARK: - Edge Tab Manager + Singleton

extension EdgeTabManager {
    
    static let shared = EdgeTabManager()
    
    /// Convenience method to show edge tab from anywhere in the app
    static func show() {
        shared.showTab()
    }
    
    /// Convenience method to hide edge tab from anywhere in the app
    static func hide() {
        shared.hideTab()
    }
    
    /// Convenience method to toggle edge tab from anywhere in the app
    static func toggle() {
        shared.toggleTab()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let edgeTabClicked = Notification.Name("EdgeTabClicked")
}

// MARK: - SwiftUI Preview

#if DEBUG
struct EdgeTabView_Previews: PreviewProvider {
    static var previews: some View {
        EdgeTabView {
            print("Tab clicked!")
        }
        .frame(width: 20, height: 100)
        .background(Color.black.opacity(0.3))
        .previewDisplayName("Edge Tab")
    }
}
#endif
