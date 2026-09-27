import SwiftUI
import AppKit
import ImageIO

struct ScreenshotItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let filename: String
    let creationDate: Date
    let fileSizeString: String
    let thumbnail: NSImage?
    let dimensions: CGSize?
    
    static func == (lhs: ScreenshotItem, rhs: ScreenshotItem) -> Bool {
        lhs.url == rhs.url && lhs.creationDate == rhs.creationDate
    }
}

@MainActor
class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()
    
    @Published var items: [ScreenshotItem] = []
    @Published var isLoading = false
    @Published var copiedItemId: UUID? = nil
    
    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: Int32 = -1
    
    var screenshotDirectory: URL {
        if let customLocation = UserDefaults.standard.persistentDomain(forName: "com.apple.screencapture")?["location"] as? String {
            let expanded = NSString(string: customLocation).expandingTildeInPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: expanded)
            }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }
    
    init() {
        loadScreenshots()
        startWatchingDirectory()
    }
    
    
    func refresh() {
        loadScreenshots()
    }
    
    func loadScreenshots() {
        let dir = screenshotDirectory
        let allowedExtensions = Set(["png", "jpg", "jpeg", "heic", "tiff"])
        
        guard let fileUrls = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        
        // Filter for screenshot files or recent image files
        let screenshotFiles = fileUrls.filter { url in
            let ext = url.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { return false }
            
            let name = url.lastPathComponent
            let isScreenshotName = name.contains("Снимок") ||
                                   name.contains("Screenshot") ||
                                   name.contains("Screen Shot") ||
                                   name.contains("Capture") ||
                                   name.contains("Shottr") ||
                                   name.contains("CleanShot")
            
            if isScreenshotName { return true }
            
            // Or recent image within last 3 days
            if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               modDate > Date().addingTimeInterval(-3 * 86400) {
                return true
            }
            return false
        }
        
        // Sort newest first
        let sorted = screenshotFiles.sorted { u1, u2 in
            let d1 = (try? u1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let d2 = (try? u2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return d1 > d2
        }
        
        // Take top 25 recent screenshots
        let recentUrls = Array(sorted.prefix(25))
        
        var loadedItems: [ScreenshotItem] = []
        for url in recentUrls {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let date = values?.contentModificationDate ?? Date()
            let sizeBytes = values?.fileSize ?? 0
            let sizeString = ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
            
            let (thumbnail, dimensions) = createThumbnail(for: url, maxPixelSize: 320)
            
            loadedItems.append(
                ScreenshotItem(
                    id: UUID(),
                    url: url,
                    filename: url.lastPathComponent,
                    creationDate: date,
                    fileSizeString: sizeString,
                    thumbnail: thumbnail,
                    dimensions: dimensions
                )
            )
        }
        
        self.items = loadedItems
    }
    
    // MARK: - Actions
    func open(item: ScreenshotItem) {
        NSWorkspace.shared.open(item.url)
    }
    
    func edit(item: ScreenshotItem) {
        let previewAppUrl = URL(fileURLWithPath: "/System/Applications/Preview.app")
        NSWorkspace.shared.open(
            [item.url],
            withApplicationAt: previewAppUrl,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, _ in }
    }
    
    func copyImage(item: ScreenshotItem) {
        guard let image = NSImage(contentsOf: item.url) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image, item.url as NSURL])
        
        self.copiedItemId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.copiedItemId == item.id {
                self?.copiedItemId = nil
            }
        }
    }
    
    func copyPath(item: ScreenshotItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.url.path, forType: .string)
    }
    
    func delete(item: ScreenshotItem) {
        try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
        withAnimation(.spring) {
            self.items.removeAll { $0.id == item.id }
        }
    }
    
    func captureArea() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
        
        NotchStateCoordinator.shared.close(force: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd 'в' HH.mm.ss"
            let filename = "Снимок экрана \(formatter.string(from: Date())).png"
            let targetUrl = self.screenshotDirectory.appendingPathComponent(filename)
            
            task.arguments = ["-i", targetUrl.path]
            
            task.terminationHandler = { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self?.loadScreenshots()
                    NotchStateCoordinator.shared.open(tab: .screenshots)
                }
            }
            
            try? task.run()
        }
    }
    
    // MARK: - Directory Watcher
    private var pendingReloadTask: Task<Void, Never>?
    
    private func startWatchingDirectory() {
        let dirUrl = screenshotDirectory
        let fd = Darwin.open(dirUrl.path, O_EVTONLY)
        guard fd >= 0 else { return }
        self.directoryFileDescriptor = fd
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .link, .rename],
            queue: DispatchQueue.main
        )
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.pendingReloadTask?.cancel()
            self.pendingReloadTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                self?.loadScreenshots()
            }
        }
        
        source.setCancelHandler {
            Darwin.close(fd)
        }
        
        source.resume()
        self.directorySource = source
    }
    
    private func stopWatching() {
        directorySource?.cancel()
        directorySource = nil
        directoryFileDescriptor = -1
    }
    
    // MARK: - Fast Hardware-Accelerated Thumbnail Generator
    private func createThumbnail(for url: URL, maxPixelSize: CGFloat) -> (NSImage?, CGSize?) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return (nil, nil) }
        
        var size: CGSize? = nil
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            if let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
               let height = properties[kCGImagePropertyPixelHeight] as? CGFloat {
                size = CGSize(width: width, height: height)
            }
        }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return (nil, size)
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return (nsImage, size)
    }
}
