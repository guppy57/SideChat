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

// MARK: - Inline Image Preview

/// Minimal image preview for inside the input field
struct InlineImagePreview: View {
    let imageData: Data
    let onRemove: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .overlay(
                        // Small remove button
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 18, height: 18)
                                )
                        }
                        .buttonStyle(.plain)
                        .offset(x: -4, y: 4),
                        alignment: .topTrailing
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Inline Images Preview with Wrapping

/// Preview for multiple images with wrapping layout inside the input field
struct InlineImagesPreview: View {
    @Binding var images: [Data]
    
    var body: some View {
        WrappingHStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, imageData in
                if let nsImage = NSImage(data: imageData) {
                    let aspectRatio = nsImage.size.width / nsImage.size.height
                    
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .frame(width: 60 * aspectRatio, height: 60)
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .overlay(
                            // Small remove button
                            Button(action: { removeImage(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 18, height: 18)
                                    )
                            }
                            .buttonStyle(.plain)
                            .offset(x: -4, y: 4),
                            alignment: .topTrailing
                        )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func removeImage(at index: Int) {
        guard images.indices.contains(index) else { return }
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            images.remove(at: index)
        }
    }
}

// MARK: - Wrapping HStack Layout

/// Custom layout that wraps content to new rows when it exceeds available width
struct WrappingHStack: Layout {
    var alignment: VerticalAlignment = .center
    var spacing: CGFloat = 8
    var horizontalAlignment: HorizontalAlignment = .leading
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            alignment: alignment,
            spacing: spacing,
            horizontalAlignment: horizontalAlignment
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            alignment: alignment,
            spacing: spacing,
            horizontalAlignment: horizontalAlignment
        )
        
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.positions[index].x + bounds.minX,
                                     y: result.positions[index].y + bounds.minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, alignment: VerticalAlignment, spacing: CGFloat, horizontalAlignment: HorizontalAlignment) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var positions: [CGPoint] = []
            var rowRanges: [(start: Int, end: Int, height: CGFloat, width: CGFloat)] = []
            var currentRowStart = 0
            var currentRowWidth: CGFloat = 0
            
            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)
                
                // Check if we need to wrap (exclude spacing from the check)
                let needsWrap = currentX > 0 && (currentX + size.width) > maxWidth
                
                if needsWrap {
                    // Save current row info
                    rowRanges.append((start: currentRowStart, end: index - 1, height: lineHeight, width: currentRowWidth))
                    
                    // Wrap to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                    currentRowStart = index
                    currentRowWidth = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                
                // Update position for next item
                currentX += size.width
                
                // Update row width (includes this item but not the trailing spacing)
                currentRowWidth = currentX
                
                // Add spacing for next item (but not at the end of a row)
                if index < subviews.count - 1 {
                    currentX += spacing
                }
                
                self.size.width = max(self.size.width, currentRowWidth)
            }
            
            // Don't forget the last row
            if currentRowStart < subviews.count {
                rowRanges.append((start: currentRowStart, end: subviews.count - 1, height: lineHeight, width: currentRowWidth))
            }
            
            self.size.height = currentY + lineHeight
            
            // Adjust positions for alignment
            for row in rowRanges {
                // Horizontal alignment adjustment
                var xOffset: CGFloat = 0
                if horizontalAlignment == .center {
                    xOffset = (maxWidth - row.width) / 2
                } else if horizontalAlignment == .trailing {
                    xOffset = maxWidth - row.width
                }
                // .leading requires no offset (xOffset = 0)
                
                for i in row.start...row.end {
                    // Apply horizontal offset
                    positions[i].x += xOffset
                    
                    // Vertical alignment within row
                    if alignment == .bottom {
                        let subview = subviews[i]
                        let size = subview.sizeThatFits(.unspecified)
                        positions[i].y += row.height - size.height
                    }
                }
            }
            
            self.positions = positions
        }
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