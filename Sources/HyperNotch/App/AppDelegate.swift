import Cocoa
import SwiftUI

class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        if let window = self.window, !window.isKeyWindow {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        super.mouseDown(with: event)
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
        
        // When closed, activate across the full closed width (including music wings) plus a generous hover buffer!
        let activeClosedWidth = max(coordinator.notchSize.width, coordinator.currentClosedSize.width) + 30
        let activeClosedHeight = coordinator.notchSize.height + 14
        let centerNotchRect = NSRect(
            x: (bounds.width - activeClosedWidth) / 2,
            y: bounds.height - activeClosedHeight,
            width: activeClosedWidth,
            height: activeClosedHeight
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
            styleMask: [.borderless],
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
        self.becomesKeyOnlyIfNeeded = false
        
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
    override var canBecomeMain: Bool { true }
    
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isCmd = flags.contains(.command)
            let isCtrl = flags.contains(.control)
            
            if isCmd || isCtrl {
                if let chars = event.charactersIgnoringModifiers?.lowercased(), let key = chars.first {
                    switch key {
                    case "a":
                        if let text = self.firstResponder as? NSText {
                            text.selectAll(nil)
                            return
                        }
                        if let responder = self.firstResponder, responder.tryToPerform(#selector(NSText.selectAll(_:)), with: nil) {
                            return
                        }
                        if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) {
                            return
                        }
                    case "c":
                        if let text = self.firstResponder as? NSText {
                            text.copy(nil)
                            return
                        }
                        if let responder = self.firstResponder, responder.tryToPerform(#selector(NSText.copy(_:)), with: nil) {
                            return
                        }
                        if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) {
                            return
                        }
                    case "v":
                        if let text = self.firstResponder as? NSText {
                            text.paste(nil)
                            return
                        }
                        if let responder = self.firstResponder, responder.tryToPerform(#selector(NSText.paste(_:)), with: nil) {
                            return
                        }
                        if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) {
                            return
                        }
                    case "x":
                        if let text = self.firstResponder as? NSText {
                            text.cut(nil)
                            return
                        }
                        if let responder = self.firstResponder, responder.tryToPerform(#selector(NSText.cut(_:)), with: nil) {
                            return
                        }
                        if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) {
                            return
                        }
                    case "z":
                        let sel = flags.contains(.shift) ? Selector(("redo:")) : Selector(("undo:"))
                        if let responder = self.firstResponder, responder.tryToPerform(sel, with: nil) {
                            return
                        }
                        if NSApp.sendAction(sel, to: nil, from: self) {
                            return
                        }
                    default:
                        break
                    }
                }
            }
        }
        super.sendEvent(event)
    }
    
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
        setupMainMenu()
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
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit HyperNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Edit Menu - ESSENTIAL for system-wide Cmd+C, Cmd+V, Cmd+A, Cmd+X, Cmd+Z dispatch
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc func screenParametersDidChange() {
        updateWindowPosition()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles.rectangle.stack.fill", accessibilityDescription: "HyperNotch")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "HyperNotch v1.5", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Toggle Notch", action: #selector(toggleNotch), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Clear File Shelf", action: #selector(clearShelf), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Refresh AI Quotas", action: #selector(refreshAI), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit HyperNotch", action: #selector(quitApp), keyEquivalent: "q"))
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
