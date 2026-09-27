import SwiftUI
import AppKit

struct ShelfView: View {
    @ObservedObject var manager = ShelfManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // Unified Hero Header
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.4), radius: 3)
                    
                    Text(loc("FILE SHELF & DROP ZONE", "ПОЛКА ФАЙЛОВ & ДРОП-ЗОНА"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                // Status banner notification
                if let status = manager.statusMessage {
                    Text(status)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                        .transition(.opacity)
                }
                
                Spacer()
                
                if !manager.items.isEmpty {
                    Text(loc("\(manager.items.count) FILES", "\(manager.items.count) ФАЙЛОВ"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    
                    Button(loc("Clear", "Очистить")) {
                        withAnimation(.spring) {
                            manager.clearAll()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .padding(.horizontal, 16)
            
            // Content Area
            if manager.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(manager.isTargeted ? 0.7 : 0.3), radius: 6)
                    
                    Text(loc("Drag and drop files here for quick stash", "Перетащите файлы сюда для быстрого стэша"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Text(loc("WebP/PNG conversion • Copy Base64 URI • AirDrop • Token estimation", "Конвертация в WebP/PNG • Копирование Base64 URI • AirDrop • Подсчет токенов"))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(
                            manager.isTargeted ? Color.white : Color.white.opacity(0.18),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(Color.white.opacity(manager.isTargeted ? 0.08 : 0.02))
                        )
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(manager.items) { item in
                            ShelfCardView(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

struct ShelfCardView: View {
    let item: ShelfItem
    @ObservedObject var manager = ShelfManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    @State private var isHovering = false
    @State private var copiedPath = false
    @State private var copiedBase64 = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Header
            HStack(spacing: 8) {
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                    .shadow(color: .white.opacity(0.15), radius: 3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 5) {
                        Text(item.sizeString)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                        
                        Text("~\(item.tokenEstimate) tok")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.cyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer(minLength: 4)
                
                Button(action: {
                    withAnimation {
                        manager.remove(id: item.id)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            
            // Primary & Quick Conversion Actions
            HStack(spacing: 4) {
                if item.isImage {
                    // Base64 Button
                    Button(action: {
                        manager.copyBase64(for: item)
                        copiedBase64 = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedBase64 = false
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: copiedBase64 ? "checkmark" : "bolt.fill")
                                .font(.system(size: 8))
                            Text(copiedBase64 ? "URI✓" : "Base64")
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(Color.purple.opacity(0.2))
                        .foregroundStyle(copiedBase64 ? Color.green : Color.purple.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    
                    // Convert button (WebP if not webp, or PNG if webp)
                    let targetFormat: ImageTargetFormat = item.url.pathExtension.lowercased() == "webp" ? .png : .webp
                    Button(action: {
                        manager.convertImage(item: item, to: targetFormat)
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 8))
                            Text("→\(targetFormat.rawValue)")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(Color.blue.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Path button
                    Button(action: {
                        manager.copyPath(for: item)
                        copiedPath = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedPath = false
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: copiedPath ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 8))
                            Text(copiedPath ? "✓" : loc("Path", "Путь"))
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(copiedPath ? Color.green : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    
                    // Code content button
                    Button(action: {
                        manager.copyContent(for: item)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "curlybraces")
                                .font(.system(size: 8))
                            Text(loc("Code", "Код"))
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer(minLength: 0)
                
                // AirDrop Share
                Button(action: {
                    manager.shareAirDrop(for: item)
                }) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 9))
                        .padding(.vertical, 3)
                        .padding(.horizontal, 5)
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(loc("AirDrop", "AirDrop"))
                
                // Finder Reveal
                Button(action: {
                    manager.revealInFinder(for: item)
                }) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 9))
                        .padding(.vertical, 3)
                        .padding(.horizontal, 5)
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(loc("Reveal in Finder", "Показать в Finder"))
            }
        }
        .padding(10)
        .frame(width: 225, height: 100)
        .heroGlassCard(cornerRadius: 13, isHovered: isHovering)
        // Enable dragging OUT of the shelf back to any external app
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
        .onHover { isHovering = $0 }
    }
}
