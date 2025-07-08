import SwiftUI
import AppKit

// MARK: - Image Preview View

/// Displays a preview of selected image with remove option
struct ImagePreviewView: View {
    let imageData: Data
    let onRemove: () -> Void
    
    @State private var imageSize: String = ""
    @State private var imageDimensions: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image preview
            if let nsImage = NSImage(data: imageData) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 150)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Remove button
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .help("Remove image")
                }
                .onAppear {
                    updateImageInfo(nsImage)
                }
            }
            
            // Image info
            HStack(spacing: 12) {
                Label(imageSize, systemImage: "doc.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label(imageDimensions, systemImage: "aspectratio")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
    
    private func updateImageInfo(_ image: NSImage) {
        // Format file size
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        imageSize = formatter.string(fromByteCount: Int64(imageData.count))
        
        // Get dimensions
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        imageDimensions = "\(width) × \(height)"
    }
}

// MARK: - Multiple Images Preview

/// Container for previewing multiple images
struct MultipleImagesPreview: View {
    let images: [Data]
    let maxImages: Int = 10
    let onRemoveImage: (Int) -> Void
    let onAddImage: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(images.indices), id: \.self) { index in
                    ImagePreviewView(imageData: images[index]) {
                        onRemoveImage(index)
                    }
                }
                
                // Add more button if under limit
                if images.count < maxImages {
                    AddImageButton(action: onAddImage)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: images.isEmpty ? 0 : 200)
    }
}

// MARK: - Add Image Button

struct AddImageButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.accentColor)
                
                Text("Add Image")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, height: 150)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(isHovered ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.primary.opacity(0.3))
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Image Compression Options

struct ImageCompressionOptions: View {
    @Binding var compressionQuality: Double
    @Binding var shouldCompress: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Compress images before sending", isOn: $shouldCompress)
                .toggleStyle(.switch)
            
            if shouldCompress {
                HStack {
                    Text("Quality:")
                        .font(.caption)
                    
                    Slider(value: $compressionQuality, in: 0.1...1.0)
                        .frame(width: 150)
                    
                    Text("\(Int(compressionQuality * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ImagePreviewView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Single image preview
            if let imageData = NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil)?.tiffRepresentation {
                ImagePreviewView(imageData: imageData) {
                    print("Remove tapped")
                }
            }
            
            // Multiple images preview
            MultipleImagesPreview(
                images: [
                    NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil)?.tiffRepresentation ?? Data(),
                    NSImage(systemSymbolName: "mountain.2.fill", accessibilityDescription: nil)?.tiffRepresentation ?? Data()
                ],
                onRemoveImage: { index in
                    print("Remove image at index \(index)")
                },
                onAddImage: {
                    print("Add image tapped")
                }
            )
            
            // Compression options
            ImageCompressionOptions(
                compressionQuality: .constant(0.8),
                shouldCompress: .constant(true)
            )
        }
        .padding()
        .frame(width: 400)
    }
}
#endif