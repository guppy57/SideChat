# Product Requirements Document: SideChat - LLM Sidebar Interface

## Introduction/Overview

SideChat is a macOS application that provides instant access to Large Language Model (LLM) conversations through an elegant, unobtrusive sidebar interface. Similar to Slidepad but designed specifically for AI chat interactions, SideChat allows users to quickly engage with LLMs without managing traditional application windows. The app features a beautiful, translucent design inspired by Apple's iMessage and seamlessly integrates into the user's workflow by appearing and disappearing on demand.

## Goals

1. Provide instant, frictionless access to LLM conversations without disrupting the user's workflow
2. Create a beautiful, native macOS experience that follows Apple's design principles
3. Support multiple LLM providers with a unified, consistent interface
4. Enable users to maintain and search through their conversation history locally
5. Offer customizable UI elements while maintaining design coherence
6. Achieve < 1 second activation time from hotkey or mouse trigger

## User Stories

1. **As a developer**, I want to quickly ask an LLM about code without switching away from my IDE, so that I can maintain my flow state.

2. **As a writer**, I want to access AI assistance with a simple mouse gesture, so that I can get help with my writing without opening a separate application.

3. **As a power user**, I want to search through my previous AI conversations, so that I can find and reuse helpful responses.

4. **As a privacy-conscious user**, I want all my chat data stored locally on my machine, so that I have full control over my conversation history.

5. **As a designer**, I want to customize the appearance of the chat interface, so that it matches my aesthetic preferences and workspace.

6. **As a researcher**, I want to share images with the LLM and export conversations, so that I can document and share my AI-assisted research.

## Functional Requirements

### Core Sidebar Functionality
1. The system must display a translucent sidebar overlay that appears on top of all other windows
2. The system must allow activation via customizable hotkey (default: to be determined)
3. The system must allow activation by moving the mouse to the screen edge (default: right edge)
4. The system must display a small, always-visible tab on the chosen screen edge for click activation
5. The system must automatically hide the sidebar when the user clicks outside of it
6. The system must provide a "pin" button to keep the sidebar open regardless of outside clicks
7. The system must allow users to choose which screen edge (left or right) hosts the sidebar

### Chat Interface
8. The system must display messages in an iMessage-style interface with appropriate chat bubbles
9. The system must stream LLM responses in real-time as they are generated
10. The system must support markdown rendering within chat messages
11. The system must display individual UI elements with translucent blur backgrounds (no window-level background)
12. The system must show user messages on the right side and LLM responses on the left side
13. The system must support image uploads within the chat interface
14. The system must display typing indicators while waiting for LLM responses
15. The system must display messages starting from the bottom of the view, growing upward
16. The system must place all control buttons in a floating toolbar above the input field

### Chat Management
17. The system must automatically generate titles for new chats using LLM summarization
18. The system must allow users to manually rename chat conversations
19. The system must provide a searchable list of all previous chats (search by chat title and last message)
20. The system must allow users to create new chats via hotkey (default: Cmd+N) or UI button
21. The system must allow users to switch between existing chats
22. The system must allow users to delete entire chat conversations
23. The system must provide options to copy individual messages or entire conversations
24. The system must allow users to export chat conversations (format: markdown or JSON)

### LLM Integration
25. The system must support OpenAI API integration
26. The system must support Anthropic API integration
27. The system must support Google AI API integration
28. The system must support local model integration
29. The system must allow users to select their preferred LLM when creating a new chat
30. The system must maintain the same LLM model throughout a single chat session
31. The system must handle API errors gracefully with user-friendly error messages

### Settings & Customization
32. The system must provide a settings panel accessible from the sidebar
33. The system must allow users to configure API keys for each LLM provider
34. The system must allow users to adjust individual element transparency (0-100%)
35. The system must allow users to adjust blur intensity for UI elements
36. The system must allow users to change font family and size
37. The system must allow users to select from predefined color themes
38. The system must allow users to customize all hotkeys
39. The system must allow users to choose the default LLM provider
40. The system must provide an option to clear all chat history

### Data Storage
41. The system must store all chat data in a local SQLite database
42. The system must store user preferences and settings persistently
43. The system must handle database migrations for future updates
44. The system must never transmit chat data to external servers beyond the LLM APIs

## Non-Goals (Out of Scope)

1. Cross-device synchronization of chat history
2. Multi-window support (multiple sidebars open simultaneously)
3. Voice input/output capabilities
4. LLM fine-tuning or training features
5. Collaborative chat features (sharing with other users)
6. Chat folders or advanced organization beyond search
7. Deleting individual messages within a chat
8. Custom LLM provider integration beyond the four specified
9. Windows or Linux support
10. iOS/iPadOS companion app

## Design Considerations

### Visual Design
- Follow Apple's Human Interface Guidelines for macOS
- Implement iMessage-style chat bubbles with tails and appropriate spacing
- Use SF Symbols for all icons where applicable
- Implement smooth animations for sidebar show/hide transitions
- Ensure all text remains readable against translucent backgrounds
- Support both light and dark mode with automatic switching
- **Floating UI Design**: All interface elements float directly on the desktop with individual translucent backgrounds
- **No window background**: The sidebar window itself should be completely transparent
- **Individual element blur**: Each UI component (chat bubbles, input field, toolbar) has its own blurred background
- **Bottom-up Chat Flow**: Messages start from bottom and populate upward, similar to modern messaging apps
- **Consolidated Controls**: All controls (pin, settings, etc.) in a unified floating toolbar above input field

### User Experience
- Sidebar width should be responsive but have sensible min/max constraints
- Keyboard navigation should be fully supported within the chat interface
- Loading states should be clearly indicated with appropriate animations
- Error messages should be helpful and actionable
- Settings should be easily discoverable but not intrusive

## Technical Considerations

### Architecture
- Built entirely with SwiftUI for modern, maintainable code
- Use Combine framework for reactive data flow
- Implement MVVM architecture pattern
- Use async/await for all API communications

### Dependencies
- SQLite for local data storage
- Each LLM provider's official SDK or REST API
- Markdown rendering library compatible with SwiftUI
- Keyboard shortcut handling framework

### Performance
- Sidebar activation must feel instantaneous (< 100ms)
- LLM streaming should update UI smoothly without lag
- Search functionality should return results in real-time using simple LIKE queries
- Database queries should be optimized for large chat histories

### Security
- API keys must be stored securely in macOS Keychain
- Local database should be encrypted at rest
- No analytics or telemetry should be collected

## Success Metrics

1. **Activation Speed**: Sidebar appears within 100ms of trigger
2. **User Engagement**: Average of 10+ chat interactions per day per active user
3. **Retention**: 80% of users still actively using the app after 30 days
4. **User Satisfaction**: 4.5+ star rating on Mac App Store
5. **Performance**: Less than 50MB memory usage when idle
6. **Reliability**: Less than 0.1% crash rate
7. **Search Performance**: Return search results within 200ms for databases with 10,000+ messages using LIKE queries on chat titles and last messages

## Open Questions

1. Should we implement a quick-access command palette for power users?
2. What should be the default hotkey for showing/hiding the sidebar?
3. Should we support custom CSS for advanced theme customization?
4. Do we need to implement rate limiting for API calls to prevent accidental overuse?
5. Should there be a compact mode for smaller screens?
6. How should we handle very long conversations (performance considerations)?
7. Should we add support for code syntax highlighting within markdown?
8. Do we need an onboarding flow for first-time users?
9. Should we implement conversation templates or prompts library in the future?
10. What analytics (if any) would be acceptable to users for improving the product?