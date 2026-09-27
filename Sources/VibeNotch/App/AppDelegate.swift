import Cocoa
import SwiftUI

class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        let coordinator = NotchStateCoordinator.shared
        
        if coordinator.isExpanded {
            let activeWidth = coordinator.openSize.width
            let activeHeight = coordinator.openSize.height
            let notchRect = NSRect(
                x: (bounds.width - activeWidth) / 2,
                y: bounds.height - activeHeight,
                width: activeWidth,
                height: activeHeight
            )
            if notchRect.contains(point) {
                return super.hitTest(point)
            }
            return nil
        }
        
        // When closed, ONLY intercept events in the center physical notch area!
        // Clicks over the side wings pass cleanly through to the macOS menu items underneath!
        let centerNotchRect = NSRect(
            x: (bounds.width - coordinator.notchSize.width) / 2,
            y: bounds.height - coordinator.notchSize.height,
            width: coordinator.notchSize.width,
            height: coordinator.notchSize.height
        )
        if centerNotchRect.contains(point) {
            return super.hitTest(point)
        }
        
        return nil
    }
}

class NotchWindow: NSPanel, NSDraggingDestination {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.isOpaque = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isMovable = false
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.becomesKeyOnlyIfNeeded = true
        
        self.collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle
        ]
        
        self.level = .mainMenu + 3
        
        // Register drag types for instant drag-and-drop support
        self.registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            .string
        ])
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Task { @MainActor in
            NotchStateCoordinator.shared.open(tab: .shelf)
        }
        return .copy
    }
    
    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        guard let items = pboard.pasteboardItems else { return false }
        var handled = false
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString) {
                Task { @MainActor in
                    ShelfManager.shared.addFile(url: url)
                    NotchStateCoordinator.shared.open(tab: .shelf)
                }
                handled = true
            }
        }
        return handled
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NotchWindow?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupNotchWindow()
        DragDetector.shared.startMonitoring()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc func screenParametersDidChange() {
        updateWindowPosition()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles.rectangle.stack.fill", accessibilityDescription: "VibeNotch")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "VibeNotch v1.0", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Toggle Notch", action: #selector(toggleNotch), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Clear File Shelf", action: #selector(clearShelf), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Refresh AI Quotas", action: #selector(refreshAI), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit VibeNotch", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc private func toggleNotch() {
        NotchStateCoordinator.shared.toggleExpand()
    }
    
    @objc private func clearShelf() {
        ShelfManager.shared.clearAll()
    }
    
    @objc private func refreshAI() {
        Task {
            await LLMTrackerManager.shared.refreshAll()
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func setupNotchWindow() {
        guard let screen = NSScreen.main else { return }
        
        let (notchWidth, notchHeight) = calculateNotchDimensions(for: screen)
        NotchStateCoordinator.shared.notchSize = CGSize(width: notchWidth, height: notchHeight)
        
        let windowWidth: CGFloat = 820
        let windowHeight: CGFloat = 460
        let screenFrame = screen.frame
        
        let windowRect = NSRect(
            x: screenFrame.midX - (windowWidth / 2),
            y: screenFrame.maxY - windowHeight,
            width: windowWidth,
            height: windowHeight
        )
        
        let panel = NotchWindow(contentRect: windowRect)
        let hostingView = NotchHostingView(rootView: MainNotchView())
        panel.contentView = hostingView
        
        self.window = panel
        panel.orderFrontRegardless()
    }
    
    private func updateWindowPosition() {
        guard let screen = NSScreen.main, let window = self.window else { return }
        
        let (notchWidth, notchHeight) = calculateNotchDimensions(for: screen)
        NotchStateCoordinator.shared.notchSize = CGSize(width: notchWidth, height: notchHeight)
        
        let windowWidth: CGFloat = 820
        let windowHeight: CGFloat = 460
        let screenFrame = screen.frame
        
        let newRect = NSRect(
            x: screenFrame.midX - (windowWidth / 2),
            y: screenFrame.maxY - windowHeight,
            width: windowWidth,
            height: windowHeight
        )
        
        window.setFrame(newRect, display: true)
    }
    
    private func calculateNotchDimensions(for screen: NSScreen) -> (CGFloat, CGFloat) {
        var notchWidth: CGFloat = 190
        var notchHeight: CGFloat = 34
        
        if let topLeft = screen.auxiliaryTopLeftArea?.width,
           let topRight = screen.auxiliaryTopRightArea?.width {
            let calculatedWidth = screen.frame.width - topLeft - topRight + 4
            if calculatedWidth > 50 {
                notchWidth = calculatedWidth
            }
        }
        
        if screen.safeAreaInsets.top > 0 {
            notchHeight = screen.safeAreaInsets.top
        }
        
        return (notchWidth, notchHeight)
    }
}
