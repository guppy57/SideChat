# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SideChat is a macOS application that provides instant access to Large Language Model (LLM) conversations through an elegant, unobtrusive sidebar interface. Similar to Slidepad but designed specifically for AI chat interactions, SideChat allows users to quickly engage with LLMs without managing traditional application windows. The app features a beautiful, translucent design inspired by Apple's iMessage and seamlessly integrates into the user's workflow by appearing and disappearing on demand.

### Key Features
- **Overlay Sidebar**: Translucent floating window that appears on top of all applications
- **Multiple LLM Support**: OpenAI, Anthropic, Google AI, and local model integration
- **iMessage-style Chat Interface**: Beautiful chat bubbles with streaming responses
- **Hotkey & Mouse Activation**: Global shortcuts and screen edge detection
- **Local Data Storage**: SQLite database with encryption for privacy
- **Customizable UI**: Themes, transparency, fonts, and layout options
- **Launch at Login**: Optional system startup integration

## Development Commands

### Build
```bash
# Build for Debug
xcodebuild -project SideChat.xcodeproj -scheme SideChat -configuration Debug build

# Build for Release  
xcodebuild -project SideChat.xcodeproj -scheme SideChat -configuration Release build

# Clean build folder
xcodebuild -project SideChat.xcodeproj -scheme SideChat clean
```

### Run
```bash
# Build and run (command line)
xcodebuild -project SideChat.xcodeproj -scheme SideChat -configuration Debug -derivedDataPath build
open build/Build/Products/Debug/SideChat.app

# Open in Xcode (recommended for development)
open SideChat.xcodeproj
```

### Test
```bash
# Run all tests
xcodebuild test -project SideChat.xcodeproj -scheme SideChat -destination 'platform=macOS'

# Run unit tests only
xcodebuild test -project SideChat.xcodeproj -scheme SideChat -only-testing:SideChatTests -destination 'platform=macOS'

# Run UI tests only  
xcodebuild test -project SideChat.xcodeproj -scheme SideChat -only-testing:SideChatUITests -destination 'platform=macOS'
```

## Swift Package Dependencies

The following packages are already installed in this project:

- **SQLite.swift**: `https://github.com/stephencelis/SQLite.swift` (v0.15.4+) - Type-safe SQLite database wrapper
- **KeychainAccess**: `https://github.com/kishikawakatsumi/KeychainAccess` (master branch) - Simple Swift wrapper for Keychain
- **KeyboardShortcuts**: `https://github.com/sindresorhus/KeyboardShortcuts` (v2.3.0+) - User-customizable global keyboard shortcuts
- **MarkdownUI**: `https://github.com/gonzalezreal/swift-markdown-ui` (v2.4.1+) - Display and customize Markdown text in SwiftUI
- **LaunchAtLogin-Modern**: `https://github.com/sindresorhus/LaunchAtLogin-Modern` (main branch) - Launch at login functionality for macOS 13+
- **Defaults**: `https://github.com/sindresorhus/Defaults` (v9.0.3+) - Swifty and modern UserDefaults with SwiftUI integration

### Package Management Commands

```bash
# Resolve package dependencies
xcodebuild -resolvePackageDependencies -project SideChat.xcodeproj -scheme SideChat

# Update packages to latest versions
xcodebuild -resolvePackageDependencies -project SideChat.xcodeproj -scheme SideChat

# Clean and resolve packages
xcodebuild clean -project SideChat.xcodeproj -scheme SideChat
xcodebuild -resolvePackageDependencies -project SideChat.xcodeproj -scheme SideChat
```

## Code Architecture

### Project Structure
- **SideChat/Models/**: Core data models (Chat, Message, LLMProvider)
- **SideChat/Database/**: SQLite database management with encryption
- **SideChat/Views/**: SwiftUI views (SidebarView, ChatView, SettingsView, etc.)
- **SideChat/ViewModels/**: MVVM view models for reactive UI updates
- **SideChat/Services/**: LLM API integration (OpenAI, Anthropic, Google AI, Local)
- **SideChat/Utilities/**: Helper classes (KeychainManager, HotkeyManager, DefaultsManager)
- **SideChat/Extensions/**: SwiftUI extensions for blur effects and custom modifiers
- **SideChatTests/**: Unit tests using Swift Testing framework
- **SideChatUITests/**: UI tests using XCTest framework

### Key Technical Details
- **Platform**: macOS 15.4+ (Sequoia and above)
- **UI Framework**: SwiftUI with AppKit integration via NSViewRepresentable
- **Architecture**: MVVM pattern with Combine for reactive programming
- **Database**: SQLite with SQLCipher encryption
- **Settings**: Defaults package with @Default property wrappers
- **Security**: Keychain for API key storage, local-only data processing
- **Bundle ID**: com.armaangupta57.SideChat
- **Code Signing**: Automatic with team ID 3Z8BWG9G9Y

### Settings Management
**Always use the Defaults package for user settings**:
```swift
import Defaults

extension Defaults.Keys {
    static let sidebarEdge = Key<SidebarEdge>("sidebarEdge", default: .right)
    static let transparency = Key<Double>("transparency", default: 0.8)
    static let blurIntensity = Key<Double>("blurIntensity", default: 0.5)
}

// In SwiftUI views
@Default(.sidebarEdge) var sidebarEdge
@Default(.transparency) var transparency
```

### Window Management
- Use `NSWindow` with `NSWindowStyleMask.borderless` and `.nonactivatingPanel`
- Implement `NSVisualEffectView` with `NSViewRepresentable` for translucent effects
- Set window level with `NSWindow.Level.floating` or `.popUpMenu`
- Handle multiple monitor setups for edge detection

### LLM Integration
- Implement streaming with `URLSession.shared.bytes(for:)` and `AsyncSequence`
- Parse Server-Sent Events (SSE) for real-time responses
- Use extended timeout configurations (360s) for reasoning models
- Support image inputs and markdown rendering

## Development Workflow

1. **Foundation First**: Set up Defaults package and settings infrastructure before other features
2. **Use Package Dependencies**: Leverage sindresorhus packages for common functionality
3. **Follow SwiftUI Patterns**: Use @State, @Binding, @ObservableObject, and @Default appropriately
4. **MVVM Architecture**: Keep business logic in ViewModels, UI in Views
5. **Security**: Store API keys in Keychain, encrypt local database
6. **Testing**: Write unit tests for models, services, and utilities
7. **Performance**: Target < 100ms sidebar activation, optimize for large chat histories

## Implementation Notes

### Custom UI Components
- **Chat Bubbles**: Use custom `Shape` protocol with `Path` drawing for iMessage-style tails
- **Blur Effects**: Implement `NSVisualEffectView` wrappers for native macOS blur
- **Hotkeys**: Use `KeyboardShortcuts.Name` extension and `KeyboardShortcuts.Recorder`
- **Launch Control**: Integrate `LaunchAtLogin.Toggle()` component in settings

### Database Operations
- Use SQLite.swift for type-safe queries and migrations
- Implement SQLCipher for encryption at rest
- Index chat content for fast search performance
- Handle large conversation histories efficiently

### API Integration
- Support streaming responses from all LLM providers
- Graceful error handling with user-friendly messages
- Rate limiting and request queuing
- Network connectivity checks and offline handling

## Development Priorities

Refer to `/tasks/tasks-prd-sidechat-llm-sidebar.md` for the complete implementation roadmap:

1. **Foundation & Settings** - Defaults package, LaunchAtLogin, data models
2. **Database Infrastructure** - SQLite setup with encryption
3. **Sidebar Window System** - Overlay window with hotkeys and mouse detection
4. **Chat Interface** - iMessage-style UI with streaming and markdown
5. **LLM Integration** - Multiple provider support with real-time responses
6. **Settings & Customization** - User preferences and configuration UI

## App Entitlements

The app requires specific entitlements for functionality:
- App sandbox with read-only file access for image uploads
- Network access for LLM API calls
- Accessibility permissions for global hotkeys (user must grant)

## Performance Targets

- Sidebar activation: < 100ms
- LLM response streaming: Smooth real-time updates
- Search performance: < 200ms for 10,000+ messages
- Memory usage: < 50MB when idle
- Database queries: Optimized for large chat histories