import Foundation
import AppKit
import Combine

@MainActor
class NotchTimerManager: ObservableObject {
    static let shared = NotchTimerManager()
    
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var timerLabel: String = "Фокус"
    
    private var timerCancellable: AnyCancellable?
    
    var timeString: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }
    
    func start(minutes: Int, label: String = "Фокус") {
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
        timerLabel = label
        isRunning = true
        isPaused = false
        
        startTimerLoop()
    }
    
    func pause() {
        isPaused = true
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    func resume() {
        guard isRunning, isPaused else { return }
        isPaused = false
        startTimerLoop()
    }
    
    func stop() {
        isRunning = false
        isPaused = false
        remainingSeconds = 0
        totalSeconds = 0
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    private func startTimerLoop() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                } else {
                    self.timerFinished()
                }
            }
    }
    
    private func timerFinished() {
        stop()
        NSSound(named: "Glass")?.play()
    }
}
