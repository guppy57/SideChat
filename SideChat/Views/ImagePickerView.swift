import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Image Picker View

/// A SwiftUI wrapper for NSOpenPanel to select image files
struct ImagePickerView: NSViewRepresentable {
    @Binding var selectedImageData: Data?
    @Binding var isPresented: Bool
    let maxFileSize: Int = 20 * 1024 * 1024 // 20MB
    
    func makeNSView(context: Context) -> NSView {
        return NSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented {
            DispatchQueue.main.async {
                showImagePicker()
            }
        }
    }
    
    private func showImagePicker() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [
            .png,
            .jpeg,
            .heic,
            .gif,
            .bmp,
            .tiff,
            .webP,
            UTType(filenameExtension: "jpg")!
        ]
        openPanel.title = "Select an Image"
        openPanel.message = "Choose an image to send (max 20MB)"
        openPanel.prompt = "Select"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                // Check file size
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let fileSize = attributes[.size] as? Int,
                   fileSize > maxFileSize {
                    // Show error for file too large
                    showFileSizeError()
                    isPresented = false
                    return
                }
                
                // Load image data
                if let imageData = try? Data(contentsOf: url) {
                    // Validate it's a valid image
                    if NSImage(data: imageData) != nil {
                        selectedImageData = imageData
                    } else {
                        showInvalidImageError()
                    }
                }
            }
            isPresented = false
        }
    }
    
    private func showFileSizeError() {
        let alert = NSAlert()
        alert.messageText = "File Too Large"
        alert.informativeText = "Please select an image smaller than 20MB."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showInvalidImageError() {
        let alert = NSAlert()
        alert.messageText = "Invalid Image"
        alert.informativeText = "The selected file could not be loaded as an image."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Image Drop Delegate

/// Handles drag and drop operations for images
struct ImageDropDelegate: DropDelegate {
    @Binding var droppedImageData: Data?
    @Binding var isDragTargeted: Bool
    let maxFileSize: Int = 20 * 1024 * 1024 // 20MB
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.image, .fileURL])
    }
    
    func dropEntered(info: DropInfo) {
        isDragTargeted = true
    }
    
    func dropExited(info: DropInfo) {
        isDragTargeted = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isDragTargeted = false
        
        // Try to get image data directly
        if let item = info.itemProviders(for: [.image]).first {
            item.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                DispatchQueue.main.async {
                    if let data = data,
                       data.count <= maxFileSize,
                       NSImage(data: data) != nil {
                        droppedImageData = data
                    }
                }
            }
            return true
        }
        
        // Try to get file URL
        if let item = info.itemProviders(for: [.fileURL]).first {
            _ = item.loadObject(ofClass: URL.self) { url, error in
                if let url = url,
                   let data = try? Data(contentsOf: url),
                   data.count <= maxFileSize,
                   NSImage(data: data) != nil {
                    DispatchQueue.main.async {
                        droppedImageData = data
                    }
                }
            }
            return true
        }
        
        return false
    }
}

// MARK: - Clipboard Image Handler

/// Utility to handle paste operations for images
struct ClipboardImageHandler {
    static func getImageFromClipboard() -> Data? {
        let pasteboard = NSPasteboard.general
        
        // Check for image types
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .tiff,
            .png,
            .pdf
        ]
        
        guard let type = pasteboard.availableType(from: imageTypes) else {
            return nil
        }
        
        guard let data = pasteboard.data(forType: type) else {
            return nil
        }
        
        // Validate it's a valid image
        guard NSImage(data: data) != nil else {
            return nil
        }
        
        // Check size (20MB limit)
        if data.count > 20 * 1024 * 1024 {
            return nil
        }
        
        return data
    }
}

// MARK: - Image Utilities

extension Data {
    /// Compress image data to fit within size limit while maintaining quality
    func compressedImageData(maxSizeKB: Int = 1024) -> Data? {
        guard let nsImage = NSImage(data: self) else { return nil }
        
        // Start with high quality
        var compression: CGFloat = 0.9
        var imageData = self
        
        // Try different compression levels
        while imageData.count > maxSizeKB * 1024 && compression > 0.1 {
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compression]) else {
                return nil
            }
            imageData = jpegData
            compression -= 0.1
        }
        
        return imageData.count <= maxSizeKB * 1024 ? imageData : nil
    }
}

extension NSImage {
    /// Resize image to fit within maximum dimensions while maintaining aspect ratio
    func resized(maxWidth: CGFloat, maxHeight: CGFloat) -> NSImage? {
        let targetSize = self.size.aspectFit(within: CGSize(width: maxWidth, height: maxHeight))
        
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        
        self.draw(in: NSRect(origin: .zero, size: targetSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
}

extension CGSize {
    /// Calculate size that fits within bounds while maintaining aspect ratio
    func aspectFit(within bounds: CGSize) -> CGSize {
        let aspectWidth = bounds.width / width
        let aspectHeight = bounds.height / height
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        return CGSize(width: width * aspectRatio, height: height * aspectRatio)
    }
}