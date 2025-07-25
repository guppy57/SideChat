# Task List: SideChat - LLM Sidebar Interface

## Relevant Files

- `SideChat/Models/AppSettings.swift` - Comprehensive app settings model with validation and import/export functionality
- `SideChat/Models/Chat.swift` - Core data model for chat conversations
- `SideChat/Models/Message.swift` - Data model for individual messages
- `SideChat/Models/LLMProvider.swift` - Enum and protocols for LLM provider abstraction
- `SideChat/Database/DatabaseManager.swift` - SQLite database management using SQLite.swift package
- `SideChat/Database/DatabaseManagerTests.swift` - Unit tests for database operations
- `SideChat/Database/DatabaseSchema.swift` - Database schema definitions
- `SideChat/Database/FTSManager.swift` - Full Text Search management
- `SideChat/Views/SidebarView.swift` - Main sidebar container view with translucent background
- `SideChat/Views/ChatView.swift` - iMessage-style chat interface view
- `SideChat/Views/ChatBubbleView.swift` - Individual message bubble component
- `SideChat/Views/ChatListView.swift` - Searchable list of previous chats (replaced by inline implementation)
- `SideChat/Views/InlineChatListView.swift` - Inline chat list that replaces chat view
- `SideChat/Views/ChatListItemView.swift` - Individual chat item in list
- `SideChat/Views/TypingIndicatorView.swift` - Animated typing indicator
- `SideChat/Views/SettingsView.swift` - Settings panel for configuration
- `SideChat/Views/EdgeTabView.swift` - Always-visible edge tab for sidebar activation
- `SideChat/ViewModels/ChatViewModel.swift` - View model for chat functionality
- `SideChat/ViewModels/ChatListViewModel.swift` - View model for chat list management
- `SideChat/ViewModels/SidebarViewModel.swift` - View model for sidebar state management (not implemented)
- `SideChat/ViewModels/SettingsViewModel.swift` - View model for app settings (not implemented)
- `SideChat/Services/LLMService.swift` - LLM service protocol definition
- `SideChat/Services/MockLLMService.swift` - Mock service for testing
- `SideChat/Services/OpenAIService.swift` - OpenAI API integration (not implemented)
- `SideChat/Services/AnthropicService.swift` - Anthropic API integration (not implemented)
- `SideChat/Services/GoogleAIService.swift` - Google AI API integration (not implemented)
- `SideChat/Services/LocalModelService.swift` - Local model integration (not implemented)
- `SideChat/Services/LLMServiceTests.swift` - Unit tests for LLM services (not implemented)
- `SideChat/Utilities/KeychainManager.swift` - Secure storage for API keys using KeychainAccess package
- `SideChat/Utilities/HotkeyManager.swift` - Global hotkey registration using KeyboardShortcuts package
- `SideChat/Utilities/MarkdownRenderer.swift` - Markdown rendering using MarkdownUI package (not needed - using MarkdownUI directly)
- `SideChat/Utilities/ClipboardImageHandler.swift` - Handle image paste from clipboard
- `SideChat/Utilities/DefaultsManager.swift` - User settings management using Defaults package with comprehensive settings definitions
- `SideChat/Extensions/View+Blur.swift` - Custom blur using NSVisualEffectView and NSViewRepresentable
- `SideChat/SideChatApp.swift` - Main app configuration and lifecycle with LaunchAtLogin integration and app initialization
- `SideChat/Windows/SidebarWindow.swift` - Custom NSWindow for sidebar with edge detection
- `SideChat/Windows/SidebarWindowController.swift` - Controller for sidebar window management
- `SideChat/Windows/EdgeTabWindow.swift` - Always-visible edge tab window
- `SideChat/AppDelegate.swift` - App delegate handling window management and hotkeys

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
  - [x] 2.8 Implement Full Text Search (FTS) with FTSManager
  - [x] 2.9 Add message pagination with loadRecentMessages method

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

- [x] 4.0 Build the chat interface with iMessage-style UI
  - [x] 4.1 Create basic SidebarView placeholder with header and input (SidebarView.swift) - Refactored with bottom-up layout
  - [x] 4.2 Create ChatView with scrollable message list
  - [x] 4.3 Implement ChatBubbleView using custom Shape with Path-based tail drawing
  - [x] 4.4 Add proper message alignment (user right, LLM left)
  - [x] 4.5 Implement markdown rendering using MarkdownUI package
  - [x] 4.6 Add image upload and display functionality
  - [x] 4.10 Create proper chat input field with multiline support - Already implemented in SidebarView
  - [x] 4.18 Create ChatViewModel to manage chat state and operations - PRIORITY: Foundation for all chat features
  - [x] 4.11 Add send button functionality and keyboard shortcuts - Connect to ChatViewModel
  - [x] 4.22 Create MockLLMService for testing streaming and responses
  - [x] 4.7 Create typing indicator for LLM responses
  - [x] 4.9 Add message copy functionality for individual messages
  - [x] 4.12 Implement ChatListView with searchable chat history - Replaced with inline chat list
  - [x] 4.24 Implement inline chat list that replaces chat view with animations
  - [x] 4.25 Add chat list filtering by provider and search functionality
  - [x] 4.26 Implement auto-scroll to bottom when switching chats
  - [x] 4.27 Add performance optimizations (LazyVStack, pagination, conditional rendering)
  - [x] 4.13 Add chat creation UI with LLM provider selection - New chat button in toolbar
  - [x] 4.14 Implement chat renaming functionality - Context menu on chat header
  - [x] 4.19 Create SidebarViewModel for overall sidebar state management - Not needed with current architecture
  - [ ] 4.15 Add individual llm or user chat deletion without any confirmation dialog by adding new option to context menu
  - [ ] 4.15.1 Add entire chat delete with a confirmation dialog
  - [ ] 4.28 Add entire chat archiving with confirmation dialog
  - [ ] 4.29 Add active/archived filtering in inline chat list
  - [ ] 4.30 Implement "Load More" button for viewing older messages
  - [ ] 4.16 Create chat export functionality (markdown/JSON)
  - [x] 4.20 Create BlurredContainer component for consistent translucent backgrounds
  - [x] 4.21 Implement bottom-anchored chat list with reverse scroll behavior
  - [x] 4.17 Add loading states and error handling throughout UI - Basic implementation done

- [ ] 5.0 Integrate LLM providers and API services
  - [x] 5.1 Create KeychainManager for secure API key storage
  - [x] 5.2 Implement message streaming using URLSession.shared.bytes (infrastructure for all services) - Mock implementation done
  - [ ] 5.3 Implement OpenAIService using URLSession with streaming
  - [ ] 5.4 Implement AnthropicService with SSE parsing
  - [ ] 5.5 Implement GoogleAIService with consistent message building
  - [ ] 5.6 Implement LocalModelService for local model integration
  - [x] 5.7 Add image input support for compatible providers - UI support complete
  - [x] 5.8 Implement error handling and user-friendly messages - Basic implementation
  - [ ] 5.9 Add API rate limiting and timeout handling
  - [x] 5.10 Implement automatic chat title generation - Using first message
  - [ ] 5.11 Add LLM provider factory and selection logic
  - [ ] 5.12 Add API key validation and testing
  - [ ] 5.13 Create comprehensive unit tests for all services
  - [ ] 5.14 Add network connectivity checks
  - [x] 5.15 Implement conversation context management - Basic implementation in ChatViewModel
  - [ ] 5.16 Add token counting and usage tracking
  - [x] 5.18 Add a retry button to retry the LLM-api request for LLM produced chats - retryLastMessage in ChatViewModel

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
- ✅ Full chat interface with iMessage-style UI
- ✅ Inline chat list with search and filtering
- ✅ Message streaming and typing indicators
- ✅ Image upload and markdown rendering
- ✅ Performance optimizations (lazy loading, pagination)
- ✅ Chat management (create, rename, switch)
- ✅ Database with FTS and encryption

### In Progress
- 🔄 LLM provider integration (real services)
- 🔄 Settings interface

### Not Started
- ❌ Real LLM service implementations (OpenAI, Anthropic, Google, Local)
- ❌ Full settings UI with API key management
- ❌ Chat export functionality
- ❌ Chat deletion and archiving
- ❌ Token counting and usage tracking

## Next Priority Tasks

1. **Implement real LLM services (5.3-5.6)** - Replace MockLLMService with actual API integrations
2. **Create SettingsView (6.1)** - User interface for API key management and preferences
3. **Add chat deletion functionality (4.15)** - Allow users to delete chats with confirmation
4. **Implement chat export (4.16)** - Export conversations in markdown/JSON format
5. **Add Load More functionality** - Allow viewing messages beyond initial 100 message limit

## Notes on Current Implementation

- The sidebar window system is fully functional with edge detection, hotkeys, and animations
- The edge tab is visible and clickable with customizable appearance
- Database infrastructure is complete with encryption, FTS, and performance optimization
- All foundational packages are integrated (Defaults, LaunchAtLogin, KeyboardShortcuts, MarkdownUI, SQLite.swift)
- The app launches successfully with a working sidebar that slides in/out
- Full chat interface is implemented with inline chat list, search, and filtering
- Performance optimizations ensure smooth operation with large chat histories
- ChatViewModel manages all chat state and operations with MockLLMService for testing
- Messages persist in SQLite database with proper indexing and pagination
- UI supports image uploads, markdown rendering, and real-time streaming
- Chat management features include create, rename, and switch functionality
