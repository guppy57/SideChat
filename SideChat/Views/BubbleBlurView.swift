import SwiftUI
import AppKit

// MARK: - Bubble Blur View

/// A custom NSVisualEffectView that clips to bubble shape and provides proper vibrancy
struct BubbleBlurView: NSViewRepresentable {
    let isUser: Bool
    let colorTheme: ColorTheme
    @Environment(\.colorScheme) var colorScheme
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        
        // Create the visual effect view
        let effectView = NSVisualEffectView()
        if isUser {
            effectView.material = .underWindowBackground
        } else {
            effectView.material = colorScheme == .dark ? .menu : .popover
        }
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
        
        // Update material based on user type and theme
        if isUser {
            effectView.material = .underWindowBackground
        } else {
            // Theme-aware material for bot messages
            effectView.material = colorScheme == .dark ? .menu : .popover
        }
        
        // Apply color tint for messages
        if isUser {
            let tintColor = colorTheme.nsColor.withAlphaComponent(0.9)
            effectView.layer?.backgroundColor = tintColor.cgColor
        } else {
            // Theme-aware tint for bot messages
            if colorScheme == .dark {
                // Dark mode: grey tint (reverting to previous)
                let greyTint = NSColor.systemGray.withAlphaComponent(0.3)
                effectView.layer?.backgroundColor = greyTint.cgColor
            } else {
                // Light mode: stronger grey for vibrancy
                let greyTint = NSColor.systemGray.withAlphaComponent(0.5)
                effectView.layer?.backgroundColor = greyTint.cgColor
            }
        }
    }
}

// MARK: - Bubble Background Wrapper

/// Combines BubbleShape clipping with blur effect
struct BubbleBackground: View {
    let isUser: Bool
    let colorTheme: ColorTheme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Base blur layer
            BubbleBlurView(isUser: isUser, colorTheme: colorTheme)
                .clipShape(BubbleShape(isFromUser: isUser))
            
            // Color overlay for messages
            if isUser {
                // Base saturated color layer
                BubbleShape(isFromUser: isUser)
                    .fill(colorTheme.color.opacity(0.7))
                
                // Second color layer for extra saturation
                BubbleShape(isFromUser: isUser)
                    .fill(colorTheme.color.opacity(0.5))
                    .blendMode(.multiply)
                
                // Gradient overlay for depth and vibrancy
                BubbleShape(isFromUser: isUser)
                    .fill(
                        LinearGradient(
                            colors: [
                                colorTheme.color.opacity(0.6),
                                colorTheme.color.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                
                // Top highlight for extra brightness
                BubbleShape(isFromUser: isUser)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            } else {
                // Bot messages - theme-aware enhancement
                if colorScheme == .dark {
                    // Dark mode: grey overlays (reverting to previous appearance)
                    
                    // Grey base overlay
                    BubbleShape(isFromUser: isUser)
                        .fill(Color.gray.opacity(0.15))
                    
                    // Subtle gradient for depth
                    BubbleShape(isFromUser: isUser)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Soft highlight
                    BubbleShape(isFromUser: isUser)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                } else {
                    // Light mode: white overlays with increased opacity for vibrancy
                    
                    // White base overlay with higher opacity
                    BubbleShape(isFromUser: isUser)
                        .fill(Color.white.opacity(0.6))
                    
                    // Light gradient for subtle depth
                    BubbleShape(isFromUser: isUser)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Bright highlight
                    BubbleShape(isFromUser: isUser)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.45),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            }
        }
    }
}

