import SwiftUI
import AppKit

// MARK: - Blurred Background View Modifier

/// A view modifier that adds a translucent blurred background to any SwiftUI view
struct BlurredBackground: ViewModifier {
    
    // MARK: - Properties
    
    /// The material type for the blur effect
    let material: NSVisualEffectView.Material
    
    /// The opacity of the blur effect (0.0 - 1.0)
    let opacity: Double
    
    /// Corner radius for the blurred background
    let cornerRadius: CGFloat
    
    /// Shadow configuration
    let shadowRadius: CGFloat
    let shadowOpacity: Double
    
    /// Padding inside the blur container
    let padding: CGFloat
    
    // MARK: - Initializer
    
    init(
        material: NSVisualEffectView.Material = .hudWindow,
        opacity: Double = 0.85,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 8,
        shadowOpacity: Double = 0.15,
        padding: CGFloat = 0
    ) {
        self.material = material
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
        self.padding = padding
    }
    
    // MARK: - Body
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                BlurredBackgroundView(
                    material: material,
                    opacity: opacity
                )
                .cornerRadius(cornerRadius)
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: 2
                )
            )
    }
}

// MARK: - NSViewRepresentable for Blur Effect

/// A SwiftUI view that wraps NSVisualEffectView for native blur effects
struct BlurredBackgroundView: NSViewRepresentable {
    
    let material: NSVisualEffectView.Material
    let opacity: Double
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = material
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.opacity = Float(opacity)
        return effectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.layer?.opacity = Float(opacity)
    }
}

// MARK: - View Extension

extension View {
    
    /// Adds a blurred background with customizable properties
    /// - Parameters:
    ///   - material: The blur material type (default: .hudWindow)
    ///   - opacity: The opacity of the blur (default: 0.85)
    ///   - cornerRadius: Corner radius for the background (default: 12)
    ///   - shadowRadius: Shadow blur radius (default: 8)
    ///   - shadowOpacity: Shadow opacity (default: 0.15)
    ///   - padding: Internal padding (default: 0)
    /// - Returns: The view with a blurred background
    func blurredBackground(
        material: NSVisualEffectView.Material = .hudWindow,
        opacity: Double = 0.85,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 8,
        shadowOpacity: Double = 0.15,
        padding: CGFloat = 0
    ) -> some View {
        self.modifier(
            BlurredBackground(
                material: material,
                opacity: opacity,
                cornerRadius: cornerRadius,
                shadowRadius: shadowRadius,
                shadowOpacity: shadowOpacity,
                padding: padding
            )
        )
    }
    
    /// Adds a light blurred background suitable for input fields
    func inputFieldBackground() -> some View {
        self.blurredBackground(
            material: .hudWindow,
            opacity: 1.0,
            cornerRadius: 8,
            shadowRadius: 6,
            shadowOpacity: 0.15,
            padding: 12
        )
    }
    
    /// Adds a prominent blurred background suitable for chat bubbles
    func chatBubbleBackground(isUser: Bool = false) -> some View {
        self.blurredBackground(
            material: isUser ? .hudWindow : .popover,
            opacity: 1.0,
            cornerRadius: 16,
            shadowRadius: 8,
            shadowOpacity: 0.2,
            padding: 12
        )
    }
    
    /// Adds a subtle blurred background suitable for toolbars
    func toolbarBackground() -> some View {
        self.blurredBackground(
            material: .hudWindow,
            opacity: 1.0,
            cornerRadius: 10,
            shadowRadius: 10,
            shadowOpacity: 0.25,
            padding: 8
        )
    }
}

// MARK: - Preview

#if DEBUG
struct BlurredBackground_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Input Field Example")
                .inputFieldBackground()
            
            Text("Chat Bubble (User)")
                .chatBubbleBackground(isUser: true)
            
            Text("Chat Bubble (Assistant)")
                .chatBubbleBackground(isUser: false)
            
            HStack {
                Image(systemName: "gear")
                Text("Toolbar")
                Image(systemName: "pin")
            }
            .toolbarBackground()
        }
        .padding()
        .frame(width: 400, height: 500)
        .background(Color.gray.opacity(0.2))
    }
}
#endif