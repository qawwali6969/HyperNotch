import Foundation
import AppKit
import Vision

@MainActor
class ScreenOCRManager: ObservableObject {
    static let shared = ScreenOCRManager()
    
    @Published var isRecognizing: Bool = false
    @Published var lastRecognizedText: String? = nil
    @Published var statusMessage: String? = nil
    
    func captureScreenAreaAndRecognize() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            self.statusMessage = "Разрешите запись экрана в Настройках"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.statusMessage = nil
            }
            return
        }
        
        isRecognizing = true
        statusMessage = "Выделите область экрана..."
        
        NotchStateCoordinator.shared.close(force: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vibenotch_ocr_\(UUID().uuidString).png")
            
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            proc.arguments = ["-i", tempUrl.path]
            
            proc.terminationHandler = { _ in
                Task { @MainActor in
                    let manager = ScreenOCRManager.shared
                    defer {
                        manager.isRecognizing = false
                        try? FileManager.default.removeItem(at: tempUrl)
                    }
                    
                    guard FileManager.default.fileExists(atPath: tempUrl.path),
                          let image = NSImage(contentsOf: tempUrl),
                          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                        manager.statusMessage = nil
                        NotchStateCoordinator.shared.open(tab: .screenshots)
                        return
                    }
                    
                    manager.recognizeText(from: cgImage)
                }
            }
            
            do {
                try proc.run()
            } catch {
                Task { @MainActor in
                    ScreenOCRManager.shared.isRecognizing = false
                    ScreenOCRManager.shared.statusMessage = nil
                    NotchStateCoordinator.shared.open(tab: .screenshots)
                }
            }
        }
    }
    
    func recognizeFromScreenshot(url: URL) {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        isRecognizing = true
        statusMessage = "Распознавание..."
        recognizeText(from: cgImage)
    }
    
    private func recognizeText(from cgImage: CGImage) {
        Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ru-RU", "en-US", "zh-Hans", "de-DE", "fr-FR", "es-ES"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            
            let observations = request.results ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let recognizedText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            
            await MainActor.run {
                ScreenOCRManager.shared.finishRecognition(lines: lines, recognizedText: recognizedText)
            }
        }
    }
    
    func finishRecognition(lines: [String], recognizedText: String) {
        self.isRecognizing = false
        
        if recognizedText.isEmpty {
            self.statusMessage = "Текст не обнаружен"
            NotchStateCoordinator.shared.open(tab: .screenshots)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.statusMessage = nil
            }
        } else {
            self.lastRecognizedText = recognizedText
            self.statusMessage = "Текст скопирован (\(lines.count) стр.)"
            
            // Copy to macOS clipboard
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(recognizedText, forType: .string)
            
            // Store into ClipboardManager history
            ClipboardManager.shared.addManualEntry(text: recognizedText)
            
            NotchStateCoordinator.shared.open(tab: .screenshots)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.statusMessage = nil
            }
        }
    }
}
