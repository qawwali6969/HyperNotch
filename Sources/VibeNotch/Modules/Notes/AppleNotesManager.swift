import Foundation
import AppKit

@MainActor
class AppleNotesManager: ObservableObject {
    static let shared = AppleNotesManager()
    
    @Published var lastSavedNoteId: String? = nil
    @Published var statusMessage: String? = nil
    
    @discardableResult
    func createNote(title: String, content: String, openApp: Bool = false) -> Bool {
        let cleanTitle = escapeHTML(title)
        let formattedDate = Date().formatted(date: .abbreviated, time: .shortened)
        
        let formattedBody: String
        let escapedContent = escapeHTML(content).replacingOccurrences(of: "\n", with: "<br>")
        formattedBody = "<h1>\(cleanTitle)</h1><p style=\"color:gray; font-size:12px;\">Сохранено из VibeNotch • \(formattedDate)</p><hr><p>\(escapedContent)</p>"
        
        // Escape AppleScript double quotes and backslashes
        let scriptSafeBody = formattedBody
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        tell application "Notes"
            set newNote to make new note with properties {body:"\(scriptSafeBody)"}
            \(openApp ? "activate" : "")
            return id of newNote
        end tell
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if error == nil, let noteId = result.stringValue {
                self.lastSavedNoteId = noteId
                self.showNotification("Заметка сохранена в Apple Notes")
                return true
            }
        }
        
        // Fallback using Process /usr/bin/osascript
        return createNoteViaProcess(body: scriptSafeBody, openApp: openApp)
    }
    
    private func createNoteViaProcess(body: String, openApp: Bool) -> Bool {
        let script = "tell application \"Notes\"\nmake new note with properties {body:\"\(body)\"}\n\(openApp ? "activate\n" : "")end tell"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                self.showNotification("Заметка сохранена в Apple Notes")
                return true
            }
        } catch {
            print("[AppleNotesManager] Process failed: \(error)")
        }
        return false
    }
    
    private func showNotification(_ message: String) {
        self.statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.statusMessage == message {
                self?.statusMessage = nil
            }
        }
    }
    
    private func escapeHTML(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
