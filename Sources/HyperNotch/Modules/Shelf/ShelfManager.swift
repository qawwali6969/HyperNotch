import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let sizeString: String
    let tokenEstimate: Int
    let icon: NSImage
    
    var isImage: Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "heic", "webp", "gif", "tiff", "bmp", "svg"].contains(ext)
    }
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        
        let fileManager = FileManager.default
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes?[.size] as? Int64) ?? 0
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        self.sizeString = formatter.string(fromByteCount: fileSize)
        
        // Fast token estimation (~4 chars per token for text, or rough heuristic)
        if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
           let str = String(data: data, encoding: .utf8) {
            self.tokenEstimate = max(1, str.count / 4)
        } else {
            // Binary or image file: approximate based on bytes
            self.tokenEstimate = Int(fileSize / 16)
        }
        
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }
    
    static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class ShelfManager: ObservableObject {
    static let shared = ShelfManager()
    
    @Published var items: [ShelfItem] = []
    @Published var isTargeted: Bool = false
    @Published var statusMessage: String? = nil
    
    init() {}
    
    func addFile(url: URL) {
        // Prevent immediate duplicates
        if !items.contains(where: { $0.url.path == url.path }) {
            let item = ShelfItem(url: url)
            items.insert(item, at: 0)
        }
    }
    
    func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }
    
    func clearAll() {
        items.removeAll()
    }
    
    func copyPath(for item: ShelfItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.url.path, forType: .string)
        showNotification("Путь скопирован")
    }
    
    func copyContent(for item: ShelfItem) {
        if let data = try? Data(contentsOf: item.url),
           let text = String(data: data, encoding: .utf8) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            showNotification("Код скопирован в буфер")
        } else {
            copyPath(for: item)
        }
    }
    
    func copyBase64(for item: ShelfItem) {
        if let dataURI = ShelfConverter.generateDataURI(for: item.url) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(dataURI, forType: .string)
            showNotification("Data URI (Base64) скопирован")
        } else {
            showNotification("Ошибка чтения файла")
        }
    }
    
    func convertImage(item: ShelfItem, to format: ImageTargetFormat) {
        Task {
            showNotification("Конвертация в \(format.rawValue)...")
            if let convertedURL = await ShelfConverter.convertImage(at: item.url, to: format) {
                self.addFile(url: convertedURL)
                self.showNotification("Готово: \(convertedURL.lastPathComponent)")
            } else {
                self.showNotification("Ошибка конвертации")
            }
        }
    }
    
    func shareAirDrop(for item: ShelfItem) {
        if let airdrop = NSSharingService(named: .sendViaAirDrop), airdrop.canPerform(withItems: [item.url]) {
            airdrop.perform(withItems: [item.url])
        } else {
            let picker = NSSharingServicePicker(items: [item.url])
            if let window = NSApp.keyWindow, let contentView = window.contentView {
                picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
            }
        }
    }
    
    func revealInFinder(for item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    
    func showNotification(_ message: String) {
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.statusMessage == message {
                self?.statusMessage = nil
            }
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var didLoadAny = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                didLoadAny = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        if let url = item as? URL {
                            Task { @MainActor [weak self] in
                                self?.addFile(url: url)
                            }
                        }
                        return
                    }
                    Task { @MainActor [weak self] in
                        self?.addFile(url: url)
                    }
                }
            }
        }
        return didLoadAny
    }
}
