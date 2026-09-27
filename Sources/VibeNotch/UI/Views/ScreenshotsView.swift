import SwiftUI
import AppKit

struct ScreenshotsView: View {
    @ObservedObject var manager = ScreenshotManager.shared
    
    var body: some View {
        VibeTabContainer(title: "SCREENSHOTS & CAPTURE", icon: "camera.viewfinder") {
            HStack(spacing: 8) {
                if !manager.items.isEmpty {
                    Text("\(manager.items.count) SHOTS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                
                Button(action: {
                    manager.refresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                if let status = ScreenOCRManager.shared.statusMessage {
                    Text(status)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.cyan)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.cyan.opacity(0.18))
                        .clipShape(Capsule())
                        .animation(.spring, value: ScreenOCRManager.shared.statusMessage)
                }
                
                VibeInteractiveHoverButton(
                    text: "Текст (OCR)",
                    leadingIcon: "text.viewfinder",
                    icon: "arrow.right",
                    fontSize: 9.5,
                    horizontalPadding: 8,
                    verticalPadding: 3,
                    minHeight: 22
                ) {
                    ScreenOCRManager.shared.captureScreenAreaAndRecognize()
                }
                
                VibeInteractiveHoverButton(
                    text: "Снимок",
                    leadingIcon: "camera.viewfinder",
                    icon: "plus",
                    fontSize: 9.5,
                    horizontalPadding: 8,
                    verticalPadding: 3,
                    minHeight: 22
                ) {
                    manager.captureArea()
                }
            }
        } content: {
            if manager.items.isEmpty {
                emptyStateView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(manager.items) { item in
                            ScreenshotCardView(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.6))
                .shadow(color: .white.opacity(0.3), radius: 6)
            
            Text("Снимки экрана появятся здесь автоматически")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
            
            Text("Делайте скриншоты через ⌘⇧4 или кнопку выше • Перетаскивайте прямо в чаты")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            
            VibeInteractiveHoverButton(
                text: "Сделать снимок области",
                leadingIcon: "crop",
                icon: "arrow.right",
                fontSize: 10,
                horizontalPadding: 12,
                verticalPadding: 5,
                minHeight: 26
            ) {
                manager.captureArea()
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Color.white.opacity(0.02))
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

struct ScreenshotCardView: View {
    let item: ScreenshotItem
    @ObservedObject var manager = ScreenshotManager.shared
    @State private var isHovering = false
    
    private var isCopied: Bool {
        manager.copiedItemId == item.id
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(item.creationDate) {
            formatter.dateFormat = "Сегодня, HH:mm"
        } else {
            formatter.dateFormat = "d MMM, HH:mm"
        }
        return formatter.string(from: item.creationDate)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Thumbnail Preview Container
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.6))
                
                if let thumb = item.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(6)
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(height: 86)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(isHovering ? 0.25 : 0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                manager.open(item: item)
            }
            
            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 4) {
                    Text(formattedDate)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                    
                    if let dims = item.dimensions {
                        Text("\(Int(dims.width))×\(Int(dims.height))")
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    
                    Text(item.fileSizeString)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Action Buttons Bar
            HStack(spacing: 5) {
                Button(action: {
                    manager.open(item: item)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 8.5))
                        Text("Открыть")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    manager.edit(item: item)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil.tip.crop.circle")
                            .font(.system(size: 8.5))
                        Text("Править")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    manager.copyImage(item: item)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: 8.5))
                        Text(isCopied ? "Скопировано" : "Копия")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(isCopied ? Color.green.opacity(0.2) : Color.white.opacity(0.08))
                    .foregroundStyle(isCopied ? Color.green : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    ScreenOCRManager.shared.recognizeFromScreenshot(url: item.url)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 8.5))
                        Text("OCR")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Распознать текст в буфер обмена")
                
                Spacer(minLength: 0)
                
                Button(action: {
                    manager.delete(item: item)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(9)
        .frame(width: 215, height: 168)
        .heroGlassCard(cornerRadius: 12, isHovered: isHovering)
        // Native macOS Drag-out to Telegram, Figma, Claude, etc.
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
        .onHover { isHovering = $0 }
    }
}
