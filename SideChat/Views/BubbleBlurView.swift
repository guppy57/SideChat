import SwiftUI
import AppKit

// MARK: - Bubble Blur View

/// A custom NSVisualEffectView that clips to bubble shape and provides proper vibrancy
struct BubbleBlurView: NSViewRepresentable {
    let isUser: Bool
    let colorTheme: ColorTheme
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        
        // Create the visual effect view
        let effectView = NSVisualEffectView()
        effectView.material = isUser ? .titlebar : .menu
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        
        // Add the effect view to container
        containerView.addSubview(effectView)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let effectView = nsView.subviews.first as? NSVisualEffectView else { return }
        
        // Update material based on user type
        effectView.material = isUser ? .titlebar : .menu
        
        // Apply color tint for user messages
        if isUser {
            let tintColor = colorTheme.nsColor.withAlphaComponent(0.6)
            effectView.layer?.backgroundColor = tintColor.cgColor
        } else {
            effectView.layer?.backgroundColor = nil
        }
    }
}

// MARK: - Bubble Background Wrapper

/// Combines BubbleShape clipping with blur effect
struct BubbleBackground: View {
    let isUser: Bool
    let colorTheme: ColorTheme
    
    var body: some View {
        ZStack {
            // Base blur layer
            BubbleBlurView(isUser: isUser, colorTheme: colorTheme)
                .clipShape(BubbleShape(isFromUser: isUser))
            
            // Color overlay for user messages
            if isUser {
                // Saturated color layer
                BubbleShape(isFromUser: isUser)
                    .fill(colorTheme.color.opacity(0.4))
                
                // Gradient overlay for depth and vibrancy
                BubbleShape(isFromUser: isUser)
                    .fill(
                        LinearGradient(
                            colors: [
                                colorTheme.color.opacity(0.3),
                                colorTheme.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }
}

