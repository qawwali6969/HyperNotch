import Cocoa

@MainActor
class DragDetector {
    static let shared = DragDetector()
    
    private var hoverTimer: Timer?
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?
    private var isExpandedByDrag: Bool = false
    private var closeWorkItem: DispatchWorkItem?
    
    func startMonitoring() {
        stopMonitoring()
        
        // 1. High-frequency, zero-overhead hover detection (runs every 60ms ~ 16 FPS)
        // Works 100% reliably across all apps without requiring Accessibility permissions
        let timer = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMousePosition(NSEvent.mouseLocation)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.hoverTimer = timer
        
        // 2. Global Mouse Drag (File drop detection across any active app)
        mouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            let mouseLoc = NSEvent.mouseLocation
            guard let screen = NSScreen.main else { return }
            let frame = screen.frame
            
            let triggerWidth = max(260, NotchStateCoordinator.shared.currentClosedSize.width + 60)
            let proximityZone = CGRect(
                x: frame.midX - (triggerWidth / 2),
                y: frame.maxY - 65,
                width: triggerWidth,
                height: 65
            )
            
            if proximityZone.contains(mouseLoc) {
                Task { @MainActor [weak self] in
                    if !NotchStateCoordinator.shared.isExpanded {
                        self?.isExpandedByDrag = true
                        NotchStateCoordinator.shared.open(tab: .shelf)
                    }
                }
            }
        }
        
        // 3. Global Mouse Up (Drop finished or cancelled)
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            guard let self = self, self.isExpandedByDrag else { return }
            self.isExpandedByDrag = false
            
            let mouseLoc = NSEvent.mouseLocation
            guard let screen = NSScreen.main else { return }
            let frame = screen.frame
            
            let activeOpenRect = CGRect(
                x: frame.midX - (NotchStateCoordinator.shared.openSize.width / 2) - 10,
                y: frame.maxY - NotchStateCoordinator.shared.openSize.height - 25,
                width: NotchStateCoordinator.shared.openSize.width + 20,
                height: NotchStateCoordinator.shared.openSize.height + 25
            )
            
            if !activeOpenRect.contains(mouseLoc) {
                Task { @MainActor in
                    if !NotchStateCoordinator.shared.isPinned {
                        NotchStateCoordinator.shared.close()
                    }
                }
            }
        }
    }
    
    private func handleMousePosition(_ mouseLoc: NSPoint) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let coordinator = NotchStateCoordinator.shared
        
        if !coordinator.isExpanded {
            // Closed: generous trigger zone at top center of screen (easy to hit by moving mouse up)
            let triggerWidth = max(280, coordinator.currentClosedSize.width + 70)
            let triggerHeight = max(48, coordinator.notchSize.height + 18)
            let triggerRect = CGRect(
                x: frame.midX - (triggerWidth / 2),
                y: frame.maxY - triggerHeight,
                width: triggerWidth,
                height: triggerHeight
            )
            
            if triggerRect.contains(mouseLoc) {
                closeWorkItem?.cancel()
                closeWorkItem = nil
                coordinator.open()
            }
        } else {
            // Open: check if mouse left the open notch bounds
            guard !coordinator.isPinned else { return }
            
            let activeWidth = coordinator.openSize.width
            let activeHeight = coordinator.openSize.height
            
            let openRect = CGRect(
                x: frame.midX - (activeWidth / 2) - 25,
                y: frame.maxY - activeHeight - 25,
                width: activeWidth + 50,
                height: activeHeight + 30
            )
            
            if !openRect.contains(mouseLoc) {
                if closeWorkItem == nil {
                    let workItem = DispatchWorkItem { [weak self] in
                        Task { @MainActor in
                            let currentLoc = NSEvent.mouseLocation
                            if let s = NSScreen.main {
                                let f = s.frame
                                let checkRect = CGRect(
                                    x: f.midX - (coordinator.openSize.width / 2) - 25,
                                    y: f.maxY - coordinator.openSize.height - 25,
                                    width: coordinator.openSize.width + 50,
                                    height: coordinator.openSize.height + 30
                                )
                                if !checkRect.contains(currentLoc) && !coordinator.isPinned {
                                    coordinator.close()
                                }
                            }
                            self?.closeWorkItem = nil
                        }
                    }
                    closeWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
                }
            } else {
                closeWorkItem?.cancel()
                closeWorkItem = nil
            }
        }
    }
    
    func stopMonitoring() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
        hoverTimer?.invalidate()
        hoverTimer = nil
        if let m = mouseDraggedMonitor {
            NSEvent.removeMonitor(m)
            mouseDraggedMonitor = nil
        }
        if let m = mouseUpMonitor {
            NSEvent.removeMonitor(m)
            mouseUpMonitor = nil
        }
    }
}
