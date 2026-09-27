import Cocoa

@MainActor
class DragDetector {
    static let shared = DragDetector()
    
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?
    private var isExpandedByDrag: Bool = false
    
    func startMonitoring() {
        stopMonitoring()
        
        // Detect global mouse drag (e.g. dragging a file from Finder or another app)
        mouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            let mouseLoc = NSEvent.mouseLocation
            guard let screen = NSScreen.main else { return }
            let frame = screen.frame
            
            // Generous proximity zone around the notch (top center 320px wide, top 65px tall)
            let proximityZone = CGRect(
                x: frame.midX - 160,
                y: frame.maxY - 65,
                width: 320,
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
        
        // Detect mouse release (drop completed or cancelled)
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            guard let self = self, self.isExpandedByDrag else { return }
            self.isExpandedByDrag = false
            
            let mouseLoc = NSEvent.mouseLocation
            guard let screen = NSScreen.main else { return }
            let frame = screen.frame
            
            // Check if dropped outside the active open notch
            let activeOpenRect = CGRect(
                x: frame.midX - (NotchStateCoordinator.shared.openSize.width / 2),
                y: frame.maxY - NotchStateCoordinator.shared.openSize.height - 20,
                width: NotchStateCoordinator.shared.openSize.width,
                height: NotchStateCoordinator.shared.openSize.height + 20
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
    
    func stopMonitoring() {
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
