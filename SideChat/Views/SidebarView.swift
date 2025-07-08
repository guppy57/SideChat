import SwiftUI
import Defaults
import UniformTypeIdentifiers

// MARK: - Sidebar View

/// Main sidebar view that contains all chat interface elements
struct SidebarView: View {
    
    // MARK: - Properties
    
    @Default(.sidebarTransparency) private var transparency
    @Default(.colorTheme) private var colorTheme
    @Default(.enableImageUploads) private var enableImageUploads
    @State private var messageText = ""
    @State private var currentChatId = UUID() // TODO: Load from database or create new
    @State private var selectedImages: [Data] = []
    @State private var showImagePicker = false
    @State private var isDragTargeted = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area with chat view
            ChatView(chatId: currentChatId)
            
            // Combined input and toolbar area - iMessage style
            VStack(spacing: 0) {
                // Inline image preview if present
                if !selectedImages.isEmpty {
                    InlineImagesPreview(images: $selectedImages)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                }
                
                HStack(spacing: 8) {
                // Left toolbar buttons
                Button(action: createNewChat) {
                    Image(systemName: "plus.bubble")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .help("New Chat")
                
                Button(action: showChatList) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Chat History")
                
                // Image upload button
                if enableImageUploads {
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "photo")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.primary.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Attach Image")
                }
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)
                
                // Text input field - multi-line with auto-grow
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .lineLimit(1...5)
                    .onSubmit {
                        sendMessage()
                    }
                
                // Right toolbar buttons
                Button(action: togglePin) {
                    Image(systemName: SidebarWindowController.shared.isSidebarPinned ? "pin.fill" : "pin")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .help(SidebarWindowController.shared.isSidebarPinned ? "Unpin Sidebar" : "Pin Sidebar")
                
                Button(action: showSettings) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings")
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(accentColor)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Send Message")
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImages.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                ZStack {
                    // Solid background for better contrast
                    RoundedRectangle(cornerRadius: 20) // More rounded like iMessage
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    
                    // Blur on top
                    BlurredBackgroundView(
                        material: .sidebar,
                        opacity: 1.0
                    )
                    .cornerRadius(20)
                }
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: 10,
                    x: 0,
                    y: 3
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(16)
            .animation(.easeInOut(duration: 0.2), value: messageText)
            .animation(.easeInOut(duration: 0.2), value: selectedImages)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear) // Completely transparent background
        .onDrop(of: [.image, .fileURL], isTargeted: $isDragTargeted, perform: handleDrop)
        .overlay {
            if isDragTargeted && enableImageUploads {
                ZStack {
                    Color.black.opacity(0.7)
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 60))
                        Text("Drop image here")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                }
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.2), value: isDragTargeted)
            }
        }
        .background {
            ImagePickerView(selectedImages: $selectedImages, isPresented: $showImagePicker)
        }
        .onReceive(NotificationCenter.default.publisher(for: .paste)) { _ in
            handlePaste()
        }
    }
    
    // MARK: - Computed Properties
    
    private var accentColor: Color {
        switch colorTheme {
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .orange: return .orange
        case .gray: return .gray
        }
    }
    
    // MARK: - Actions
    
    private func createNewChat() {
        // TODO: Implement new chat creation
        print("Create new chat")
    }
    
    private func showChatList() {
        // TODO: Implement chat list display
        print("Show chat list")
    }
    
    private func togglePin() {
        let currentState = SidebarWindowController.shared.isSidebarPinned
        SidebarWindowController.shared.setSidebarPinned(!currentState)
    }
    
    private func showSettings() {
        NotificationCenter.default.post(name: .hotkeySettingsPanel, object: nil)
    }
    
    private func sendMessage() {
        // TODO: Implement message sending to LLM
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMessage.isEmpty || !selectedImages.isEmpty {
            print("Sending message: \(trimmedMessage)")
            if !selectedImages.isEmpty {
                print("With \(selectedImages.count) image(s)")
                for (index, imageData) in selectedImages.enumerated() {
                    print("  Image \(index + 1): \(imageData.count) bytes")
                }
            }
            messageText = "" // Clear the input field
            selectedImages.removeAll() // Clear all images
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard enableImageUploads else { return false }
        
        // Handle image drop
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                    DispatchQueue.main.async {
                        if let data = data,
                           data.count <= 20 * 1024 * 1024, // 20MB limit
                           NSImage(data: data) != nil {
                            selectedImages.append(data)
                        }
                        isDragTargeted = false
                    }
                }
                return true
            }
        }
        
        return false
    }
    
    private func handlePaste() {
        guard enableImageUploads else { return }
        
        if let imageData = ClipboardImageHandler.getImageFromClipboard() {
            selectedImages.append(imageData)
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let paste = Notification.Name("NSPasteboardDidChangeNotification")
}

// MARK: - Preview

#if DEBUG
struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
            .frame(width: 400, height: 600)
    }
}
#endif