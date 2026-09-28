import SwiftUI
import AppKit

struct ShelfView: View {
    @ObservedObject var manager = ShelfManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // V2 Module Header
            V2ModuleHeader(
                tab: .shelf,
                statusText: manager.statusMessage ?? (manager.items.isEmpty ? loc("EMPTY · DROP TO STASH", "ПУСТО · DROP НА ВЫРЕЗ") : loc("\(manager.items.count) FILES · DROP TO STASH", "\(manager.items.count) ФАЙЛА · DROP НА ВЫРЕЗ"))
            ) {
                if !manager.items.isEmpty {
                    V2GlassButton(title: loc("Clear", "Очистить"), icon: "trash") {
                        withAnimation(.spring) {
                            manager.clearAll()
                        }
                    }
                }
            }
            
            // Content Area
            if manager.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(V2Colors.ice1)
                        .shadow(color: V2Colors.ice.opacity(manager.isTargeted ? 0.7 : 0.25), radius: 6)
                    
                    Text(loc("Drag and drop files here for quick stash", "Перетащите файлы сюда для быстрого стэша"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(V2Colors.milk)
                    
                    Text(loc("WebP/PNG conversion • Copy Base64 URI • AirDrop • Token estimation", "Конвертация в WebP/PNG • Копирование Base64 URI • AirDrop • Подсчет токенов"))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(V2Colors.dim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(
                            manager.isTargeted ? V2Colors.ice : Color.white.opacity(0.12),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(manager.isTargeted ? V2Colors.ice.opacity(0.08) : Color.white.opacity(0.02))
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
                    .shadow(color: V2Colors.ice.opacity(0.18), radius: 3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(V2Colors.milk)
                    
                    HStack(spacing: 5) {
                        Text(item.sizeString)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(V2Colors.faint)
                        
                        Text("•")
                            .font(.system(size: 7))
                            .foregroundStyle(V2Colors.faint)
                        
                        if item.tokenEstimate > 0 {
                            Text("~\(item.tokenEstimate) tok")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(V2Colors.ice1)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(V2Colors.ice.opacity(0.12))
                                .clipShape(Capsule())
                        } else {
                            Text(item.url.pathExtension.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(V2Colors.dim)
                        }
                    }
                }
                
                Spacer(minLength: 4)
                
                Button(action: {
                    withAnimation {
                        manager.remove(id: item.id)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(V2Colors.faint)
                        .padding(4)
                        .background(Circle().fill(Color.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.06))
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
                        .background(V2Colors.ice.opacity(0.15))
                        .foregroundStyle(copiedBase64 ? Color.green : V2Colors.ice1)
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
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(V2Colors.milk)
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
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(copiedPath ? Color.green : V2Colors.dim)
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
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(V2Colors.milk)
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
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(V2Colors.dim)
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
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(V2Colors.dim)
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
