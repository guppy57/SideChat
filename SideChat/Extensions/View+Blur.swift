import SwiftUI
import AppKit

// MARK: - NSVisualEffectView SwiftUI Wrapper

/// A SwiftUI wrapper for NSVisualEffectView to provide native macOS blur effects
struct VisualEffectView: NSViewRepresentable {
    
    // MARK: - Properties
    
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State
    
    // MARK: - Initialization
    
    init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }
    
    // MARK: - NSViewRepresentable
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - View Extension for Blur Effects

extension View {
    
    /// Applies a native macOS blur effect to the view
    /// - Parameters:
    ///   - material: The visual effect material (default: .sidebar)
    ///   - blendingMode: The blending mode (default: .behindWindow)
    ///   - state: The visual effect state (default: .active)
    /// - Returns: A view with blur effect applied
    func blur(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) -> some View {
        self.background(
            VisualEffectView(
                material: material,
                blendingMode: blendingMode,
                state: state
            )
        )
    }
    
    /// Applies a sidebar-style blur effect optimized for SideChat
    /// - Parameter intensity: Blur intensity from 0.0 to 1.0 (default: 0.8)
    /// - Returns: A view with sidebar blur effect
    func sidebarBlur(intensity: Double = 0.8) -> some View {
        let material: NSVisualEffectView.Material = {
            switch intensity {
            case 0.0..<0.3:
                return .menu
            case 0.3..<0.6:
                return .popover
            case 0.6..<0.8:
                return .sidebar
            default:
                return .hudWindow
            }
        }()
        
        return self.blur(
            material: material,
            blendingMode: .behindWindow,
            state: .active
        )
    }
    
    /// Applies a translucent overlay with customizable opacity
    /// - Parameter opacity: The opacity level from 0.0 to 1.0 (default: 0.2)
    /// - Returns: A view with translucent overlay
    func translucentOverlay(opacity: Double = 0.2) -> some View {
        self.overlay(
            Rectangle()
                .fill(Color.black.opacity(opacity))
                .allowsHitTesting(false)
        )
    }
    
    /// Combines blur and translucent effects for the perfect sidebar appearance
    /// - Parameters:
    ///   - blurIntensity: Blur intensity from 0.0 to 1.0 (default: 0.8)
    ///   - opacity: Overlay opacity from 0.0 to 1.0 (default: 0.1)
    /// - Returns: A view with combined blur and translucent effects
    func sidebarBackground(blurIntensity: Double = 0.8, opacity: Double = 0.1) -> some View {
        self
            .sidebarBlur(intensity: blurIntensity)
            .translucentOverlay(opacity: opacity)
    }
}

// MARK: - Blur Material Presets

extension NSVisualEffectView.Material {
    
    /// Material presets optimized for SideChat
    static let sidebarLight: NSVisualEffectView.Material = .sidebar
    static let sidebarDark: NSVisualEffectView.Material = .hudWindow
    static let sidebarMenu: NSVisualEffectView.Material = .menu
    static let sidebarPopover: NSVisualEffectView.Material = .popover
}

// MARK: - Theme-Aware Blur

struct ThemeAwareBlur: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    let lightMaterial: NSVisualEffectView.Material
    let darkMaterial: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State
    
    init(
        lightMaterial: NSVisualEffectView.Material = .sidebar,
        darkMaterial: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.lightMaterial = lightMaterial
        self.darkMaterial = darkMaterial
        self.blendingMode = blendingMode
        self.state = state
    }
    
    var body: some View {
        VisualEffectView(
            material: colorScheme == .dark ? darkMaterial : lightMaterial,
            blendingMode: blendingMode,
            state: state
        )
    }
}

// MARK: - View Extension for Theme-Aware Blur

extension View {
    
    /// Applies theme-aware blur that adapts to light/dark mode
    /// - Parameters:
    ///   - lightMaterial: Material for light mode (default: .sidebar)
    ///   - darkMaterial: Material for dark mode (default: .hudWindow)
    /// - Returns: A view with theme-aware blur effect
    func themeAwareBlur(
        lightMaterial: NSVisualEffectView.Material = .sidebar,
        darkMaterial: NSVisualEffectView.Material = .hudWindow
    ) -> some View {
        self.background(
            ThemeAwareBlur(
                lightMaterial: lightMaterial,
                darkMaterial: darkMaterial
            )
        )
    }
}