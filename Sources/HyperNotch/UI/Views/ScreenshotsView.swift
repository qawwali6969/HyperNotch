import SwiftUI
import AppKit

struct ScreenshotsView: View {
    @ObservedObject var manager = ScreenshotManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // V2 Module Header
            V2ModuleHeader(
                tab: .screenshots,
                statusText: ScreenOCRManager.shared.statusMessage ?? loc("3-DAY FEED · LOCAL OCR", "ЛЕНТА 3 ДНЯ · OCR ЛОКАЛЬНО")
            ) {
                Button(action: {
                    manager.refresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9.5))
                        .foregroundStyle(V2Colors.dim)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                V2GlassButton(
                    title: loc("Capture", "Снимок"),
                    icon: "camera.viewfinder"
                ) {
                    manager.captureArea()
                }
                
                V2GlassButton(
                    title: loc("Text (OCR)", "Текст (OCR)"),
                    icon: "text.viewfinder",
                    isKey: true
                ) {
                    ScreenOCRManager.shared.captureScreenAreaAndRecognize()
                }
            }
            
            // Content
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
                .foregroundStyle(V2Colors.ice.opacity(0.5))
                .shadow(color: V2Colors.ice.opacity(0.2), radius: 6)
            
            Text(loc("Screenshots will appear here automatically", "Снимки экрана появятся здесь автоматически"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(V2Colors.milk)
            
            Text(loc("Take screenshots via ⌘⇧4 or the button above • Drag directly into chats", "Делайте скриншоты через ⌘⇧4 или кнопку выше • Перетаскивайте прямо в чаты"))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(V2Colors.faint)
            
            V2GlassButton(
                title: loc("Capture screen area", "Сделать снимок области"),
                icon: "crop",
                isKey: true
            ) {
                manager.captureArea()
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
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
            formatter.dateFormat = loc("'Today', HH:mm", "'Сегодня', HH:mm")
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
                    .foregroundStyle(V2Colors.milk)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 4) {
                    Text(formattedDate)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(V2Colors.faint)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(V2Colors.faint)
                    
                    if let dims = item.dimensions {
                        Text("\(Int(dims.width))×\(Int(dims.height))")
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(V2Colors.faint)
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundStyle(V2Colors.faint)
                    }
                    
                    Text(item.fileSizeString)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(V2Colors.faint)
                }
            }
            
            // Action Buttons Bar
            HStack(spacing: 4) {
                Button(action: {
                    manager.open(item: item)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 8.5))
                        Text(loc("Open", "Открыть"))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 5)
                    .background(Color.white.opacity(0.06))
                    .foregroundStyle(V2Colors.milk)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    manager.edit(item: item)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil.tip.crop.circle")
                            .font(.system(size: 8.5))
                        Text(loc("Edit", "Править"))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 5)
                    .background(Color.white.opacity(0.06))
                    .foregroundStyle(V2Colors.dim)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    manager.copyImage(item: item)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: 8.5))
                        Text(isCopied ? loc("Copied", "Скопировано") : loc("Copy", "Копия"))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 5)
                    .background(isCopied ? Color.green.opacity(0.2) : Color.white.opacity(0.06))
                    .foregroundStyle(isCopied ? Color.green : V2Colors.dim)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    ScreenOCRManager.shared.recognizeFromScreenshot(url: item.url)
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 8.5))
                        Text("OCR")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 5)
                    .background(V2Colors.ice.opacity(0.14))
                    .foregroundStyle(V2Colors.ice1)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(loc("Recognize text to clipboard", "Распознать текст в буфер обмена"))
                
                Spacer(minLength: 0)
                
                Button(action: {
                    manager.delete(item: item)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundStyle(V2Colors.faint)
                        .padding(4)
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
