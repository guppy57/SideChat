# Task List: SideChat - LLM Sidebar Interface

## Relevant Files

- `SideChat/Models/AppSettings.swift` - Comprehensive app settings model with validation and import/export functionality
- `SideChat/Models/Chat.swift` - Core data model for chat conversations
- `SideChat/Models/Message.swift` - Data model for individual messages
- `SideChat/Models/LLMProvider.swift` - Enum and protocols for LLM provider abstraction
- `SideChat/Database/DatabaseManager.swift` - SQLite database management using SQLite.swift package
- `SideChat/Database/DatabaseManagerTests.swift` - Unit tests for database operations
- `SideChat/Views/SidebarView.swift` - Main sidebar container view with translucent background
- `SideChat/Views/ChatView.swift` - iMessage-style chat interface view
- `SideChat/Views/ChatBubbleView.swift` - Individual message bubble component
- `SideChat/Views/ChatListView.swift` - Searchable list of previous chats
- `SideChat/Views/SettingsView.swift` - Settings panel for configuration
- `SideChat/Views/EdgeTabView.swift` - Always-visible edge tab for sidebar activation
- `SideChat/ViewModels/ChatViewModel.swift` - View model for chat functionality
- `SideChat/ViewModels/SidebarViewModel.swift` - View model for sidebar state management
- `SideChat/ViewModels/SettingsViewModel.swift` - View model for app settings
- `SideChat/Services/OpenAIService.swift` - OpenAI API integration
- `SideChat/Services/AnthropicService.swift` - Anthropic API integration
- `SideChat/Services/GoogleAIService.swift` - Google AI API integration
- `SideChat/Services/LocalModelService.swift` - Local model integration
- `SideChat/Services/LLMServiceTests.swift` - Unit tests for LLM services
- `SideChat/Utilities/KeychainManager.swift` - Secure storage for API keys using KeychainAccess package
- `SideChat/Utilities/HotkeyManager.swift` - Global hotkey registration using KeyboardShortcuts package
- `SideChat/Utilities/MarkdownRenderer.swift` - Markdown rendering using MarkdownUI package
- `SideChat/Utilities/DefaultsManager.swift` - User settings management using Defaults package with comprehensive settings definitions
- `SideChat/Extensions/View+Blur.swift` - Custom blur using NSVisualEffectView and NSViewRepresentable
- `SideChat/SideChatApp.swift` - Main app configuration and lifecycle with LaunchAtLogin integration and app initialization

### Notes

- Unit tests should be placed in the corresponding test directories (SideChatTests/)
- Use `xcodebuild test` to run all tests or specify individual test files
- SwiftUI previews should be included for all major views for rapid development

### Required Swift Package Dependencies

Add these packages to your Xcode project via File → Add Package Dependencies:

- **SQLite.swift**: `https://github.com/stephencelis/SQLite.swift` - Type-safe SQLite database wrapper
- **KeychainAccess**: `https://github.com/kishikawakatsumi/KeychainAccess` - Simple Swift wrapper for Keychain
- **KeyboardShortcuts**: `https://github.com/sindresorhus/KeyboardShortcuts` - User-customizable global keyboard shortcuts
- **MarkdownUI**: `https://github.com/gonzalezreal/swift-markdown-ui` - Display and customize Markdown text in SwiftUI
- **LaunchAtLogin-Modern**: `https://github.com/sindresorhus/LaunchAtLogin-Modern` - Launch at login functionality for macOS 13+
- **Defaults**: `https://github.com/sindresorhus/Defaults` - Swifty and modern UserDefaults with SwiftUI integration

### Technical Implementation Notes

- Use `NSVisualEffectView` with `NSViewRepresentable` for individual UI element blur effects (not window background)
- Window background should be completely transparent (`.clear`)
- Implement streaming with `URLSession.shared.bytes(for:)` and `AsyncSequence`
- Custom chat bubbles require `Shape` protocol with `Path` drawing for tails
- Global hotkeys need `KeyboardShortcuts.Name` extension for configuration
- Mouse edge detection uses `NSEvent.addGlobalMonitorForEvents` with screen coordinate calculations
- Window overlay requires `NSWindow.Level.floating` or `.popUpMenu` for proper layering
- Use `LaunchAtLogin.Toggle()` SwiftUI component for launch at login settings
- Replace all `UserDefaults` usage with `@Default` property wrapper from Defaults package
- Implement reversed ScrollView with flipped coordinate system for bottom-up chat
- Create reusable `BlurredBackground` ViewModifier for consistent styling

## Tasks

- [x] 1.0 Set up core foundation and settings infrastructure
  - [x] 1.1 Add Defaults package and create Defaults.Keys extension for all app settings
  - [x] 1.2 Create DefaultsManager utility class using @Default property wrappers
  - [x] 1.3 Set up LaunchAtLogin-Modern package for macOS 13+ support
  - [x] 1.4 Create app settings model with all user preferences using Defaults
  - [x] 1.5 Implement settings validation and error handling
  - [x] 1.6 Add settings migration system for future updates
  - [x] 1.7 Create Chat model with properties (id, title, createdAt, updatedAt, llmProvider, modelName)
  - [x] 1.8 Create Message model with properties (id, chatId, content, isUser, timestamp, imageData)
  - [x] 1.9 Create LLMProvider enum and protocol for provider abstraction
  - [x] 1.10 Write unit tests for settings management and data models

- [x] 2.0 Set up database infrastructure
  - [x] 2.1 Implement DatabaseManager using SQLite.swift package with type-safe queries
  - [x] 2.2 Create database schema with proper indexing for search performance
  - [x] 2.3 Implement CRUD operations for chats and messages (completed as part of DatabaseManager)
  - [x] 2.4 Add database migration system for future schema changes
  - [x] 2.5 Implement database encryption using SQLCipher integration with SQLite.swift
  - [x] 2.6 Write comprehensive unit tests for all database operations
  - [x] 2.7 Add database performance optimization for large chat histories

- [x] 3.0 Implement sidebar window management and activation system
  - [x] 3.1 Create custom NSWindow subclass with NSWindowStyleMask.borderless and .nonactivatingPanel (SidebarWindow.swift)
  - [x] 3.2 Implement translucent window using NSVisualEffectView with NSViewRepresentable wrapper (View+Blur.swift, SidebarWindow)
  - [x] 3.3 Add global hotkey registration using KeyboardShortcuts package (HotkeyManager.swift)
  - [x] 3.4 Implement mouse edge detection using NSEvent.addGlobalMonitorForEvents (SidebarWindow.swift)
  - [x] 3.5 Create always-visible edge tab that responds to clicks (EdgeTabView.swift, EdgeTabWindow)
  - [x] 3.6 Add auto-hide functionality when clicking outside sidebar (SidebarWindow.swift)
  - [x] 3.7 Implement pin/unpin functionality to keep sidebar open (SidebarWindow.swift)
  - [x] 3.8 Add user preference for left/right edge positioning using Defaults (implemented in settings)
  - [x] 3.9 Implement smooth show/hide animations with < 100ms activation time (80ms show, 60ms hide)
  - [x] 3.10 Add window level management using NSWindow.Level.floating (SidebarWindow.swift)
  - [x] 3.11 Handle multiple monitor setups and edge detection (SidebarWindow.swift)
  - [x] 3.12 Connect all components in AppDelegate for activation (AppDelegate.swift)
  - [x] 3.13 Remove NSVisualEffectView from window background, make window completely transparent
  - [x] 3.14 Implement individual blur backgrounds for UI elements (chat bubbles, input box, control toolbar)
  - [x] 3.15 Create floating toolbar component that sits below input field for controls (pin, settings, etc.) - Combined into unified input block
  - [x] 3.16 Refactor chat layout to start from bottom and grow upward with inverted scroll - Implemented with defaultScrollAnchor

- [ ] 4.0 Build the chat interface with iMessage-style UI
  - [x] 4.1 Create basic SidebarView placeholder with header and input (SidebarView.swift) - Refactored with bottom-up layout
  - [x] 4.2 Create ChatView with scrollable message list
  - [x] 4.3 Implement ChatBubbleView using custom Shape with Path-based tail drawing
  - [x] 4.4 Add proper message alignment (user right, LLM left)
  - [x] 4.5 Implement markdown rendering using MarkdownUI package
  - [ ] 4.6 Add image upload and display functionality
  - [ ] 4.7 Create typing indicator for LLM responses
  - [ ] 4.8 Implement message streaming using URLSession.shared.bytes
  - [ ] 4.9 Add message copy functionality for individual messages
  - [ ] 4.10 Create proper chat input field with multiline support
  - [ ] 4.11 Add send button functionality and keyboard shortcuts
  - [ ] 4.12 Implement ChatListView with searchable chat history
  - [ ] 4.13 Add chat creation UI with LLM provider selection
  - [ ] 4.14 Implement chat renaming functionality
  - [ ] 4.15 Add chat deletion with confirmation dialog
  - [ ] 4.16 Create chat export functionality (markdown/JSON)
  - [ ] 4.17 Add loading states and error handling throughout UI
  - [ ] 4.18 Create ChatViewModel to manage chat state and operations
  - [ ] 4.19 Create SidebarViewModel for overall sidebar state management
  - [ ] 4.20 Create BlurredContainer component for consistent translucent backgrounds
  - [ ] 4.21 Implement bottom-anchored chat list with reverse scroll behavior

- [ ] 5.0 Integrate LLM providers and API services
  - [ ] 5.1 Create KeychainManager for secure API key storage
  - [ ] 5.2 Implement OpenAIService using URLSession with streaming
  - [ ] 5.3 Implement AnthropicService with SSE parsing
  - [ ] 5.4 Implement GoogleAIService with consistent message building
  - [ ] 5.5 Implement LocalModelService for local model integration
  - [ ] 5.6 Add image input support for compatible providers
  - [ ] 5.7 Implement error handling and user-friendly messages
  - [ ] 5.8 Add API rate limiting and timeout handling
  - [ ] 5.9 Implement automatic chat title generation
  - [ ] 5.10 Add LLM provider factory and selection logic
  - [ ] 5.11 Add API key validation and testing
  - [ ] 5.12 Create comprehensive unit tests for all services
  - [ ] 5.13 Add network connectivity checks
  - [ ] 5.14 Implement conversation context management
  - [ ] 5.15 Add token counting and usage tracking
  - [ ] 5.16 Add a copy to clipboard button underneath the chats for LLMs and for the chats the user sends
  - [ ] 5.17 Add a retry button to retry the LLM-api request for LLM produced chats

- [ ] 6.0 Create settings and customization features
  - [ ] 6.1 Create SettingsView with tabbed interface
  - [ ] 6.2 Implement API key management UI with KeychainAccess
  - [ ] 6.3 Add transparency and blur intensity controls
  - [ ] 6.4 Create font customization interface
  - [ ] 6.5 Implement color theme selection
  - [ ] 6.6 Add hotkey customization using KeyboardShortcuts.Recorder
  - [ ] 6.7 Create sidebar position and size preferences
  - [ ] 6.8 Add default LLM provider selection
  - [ ] 6.9 Implement data management (clear history, export)
  - [ ] 6.10 Add appearance preferences (dark/light mode)
  - [ ] 6.11 Integrate LaunchAtLogin.Toggle() component
  - [ ] 6.12 Add settings import/export functionality
  - [ ] 6.13 Create keyboard shortcuts reference
  - [ ] 6.14 Build onboarding flow for first-time users
  - [ ] 6.15 Create SettingsViewModel for settings management

## Implementation Status

### Completed
- ✅ Core foundation (models, database, settings infrastructure)
- ✅ Window management system (sidebar window, edge tab, hotkeys)
- ✅ Basic UI scaffolding (placeholder sidebar view)

### In Progress
- 🔄 Chat interface implementation
- 🔄 LLM provider integration

### Not Started
- ❌ Full chat UI with messaging
- ❌ LLM service implementations
- ❌ Settings interface
- ❌ Advanced features (export, search, etc.)

## Next Priority Tasks

1. **Implement transparent window background (3.13)** - Remove visual effect from window
2. **Create BlurredBackground ViewModifier (4.20)** - For individual UI elements
3. **Refactor SidebarView for bottom-up layout (4.1)** - Remove header, reorganize layout
4. **Create FloatingToolbar component (3.15)** - Consolidate controls above input
5. **Implement bottom-up chat list (3.16, 4.21)** - Reverse scroll behavior

## Notes on Current Implementation

- The sidebar window system is fully functional with edge detection, hotkeys, and animations
- The edge tab is visible and clickable with customizable appearance
- Database infrastructure is complete with encryption and performance optimization
- All foundational packages are integrated (Defaults, LaunchAtLogin, KeyboardShortcuts)
- The app launches successfully with a working sidebar that slides in/out
