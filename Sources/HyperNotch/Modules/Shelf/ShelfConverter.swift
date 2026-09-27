import Foundation
import AppKit
import UniformTypeIdentifiers

enum ImageTargetFormat: String, CaseIterable {
    case webp = "WebP"
    case png = "PNG"
    case jpeg = "JPEG"
    
    var fileExtension: String {
        switch self {
        case .webp: return "webp"
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }
}

enum ShelfConverter {
    /// Converts an image file to the specified target format
    /// Returns the URL of the converted file, or nil if conversion failed
    static func convertImage(at sourceURL: URL, to format: ImageTargetFormat) async -> URL? {
        let destinationURL = sourceURL.deletingPathExtension()
            .appendingPathExtension(format.fileExtension)
        
        // If target file already exists with same name, add a suffix
        let finalURL: URL
        if FileManager.default.fileExists(atPath: destinationURL.path) && destinationURL.path != sourceURL.path {
            let uniqueName = sourceURL.deletingPathExtension().lastPathComponent + "_\(Int(Date().timeIntervalSince1970))"
            finalURL = sourceURL.deletingLastPathComponent().appendingPathComponent(uniqueName).appendingPathExtension(format.fileExtension)
        } else {
            finalURL = destinationURL
        }
        
        switch format {
        case .webp:
            return await convertToWebP(sourceURL: sourceURL, targetURL: finalURL)
        case .png, .jpeg:
            return await convertViaSips(sourceURL: sourceURL, targetURL: finalURL, format: format)
        }
    }
    
    /// Converts image using cwebp if available, or falls back to sips conversion
    private static func convertToWebP(sourceURL: URL, targetURL: URL) async -> URL? {
        let cwebpPaths = ["/opt/homebrew/bin/cwebp", "/usr/local/bin/cwebp"]
        let cwebpPath = cwebpPaths.first { FileManager.default.fileExists(atPath: $0) }
        
        if let cwebp = cwebpPath {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: cwebp)
            proc.arguments = ["-q", "85", sourceURL.path, "-o", targetURL.path]
            do {
                try proc.run()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 && FileManager.default.fileExists(atPath: targetURL.path) {
                    return targetURL
                }
            } catch {
                print("[ShelfConverter] cwebp failed: \(error)")
            }
        }
        
        // Fallback: convert via sips to PNG if cwebp is not available or failed
        let pngFallback = sourceURL.deletingPathExtension().appendingPathExtension("png")
        return await convertViaSips(sourceURL: sourceURL, targetURL: pngFallback, format: .png)
    }
    
    /// Converts image using macOS built-in sips tool
    private static func convertViaSips(sourceURL: URL, targetURL: URL, format: ImageTargetFormat) async -> URL? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        let sipsFormat = format == .jpeg ? "jpeg" : "png"
        proc.arguments = ["-s", "format", sipsFormat, sourceURL.path, "--out", targetURL.path]
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 && FileManager.default.fileExists(atPath: targetURL.path) {
                return targetURL
            }
        } catch {
            print("[ShelfConverter] sips failed: \(error)")
        }
        return nil
    }
    
    /// Generates a Data URI base64 string from an image file
    static func generateDataURI(for fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let ext = fileURL.pathExtension.lowercased()
        let mimeType: String
        switch ext {
        case "png": mimeType = "image/png"
        case "jpg", "jpeg": mimeType = "image/jpeg"
        case "webp": mimeType = "image/webp"
        case "gif": mimeType = "image/gif"
        case "svg": mimeType = "image/svg+xml"
        case "heic": mimeType = "image/heic"
        default: mimeType = "application/octet-stream"
        }
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}
