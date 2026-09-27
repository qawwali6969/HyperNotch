import SwiftUI

struct CompactTimerHUDView: View {
    @ObservedObject var timer = NotchTimerManager.shared
    
    var body: some View {
        HStack(spacing: 4) {
            if timer.isRunning {
                HStack(spacing: 4) {
                    Image(systemName: timer.isPaused ? "pause.circle.fill" : "timer")
                        .font(.system(size: 9))
                        .foregroundStyle(timer.isPaused ? Color.orange : Color.yellow)
                    
                    Text(timer.timeString)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Button(action: {
                        if timer.isPaused {
                            timer.resume()
                        } else {
                            timer.pause()
                        }
                    }) {
                        Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        timer.stop()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.12))
                        .overlay(
                            Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 0.8)
                        )
                )
            } else {
                Button(action: {
                    timer.start(minutes: 25, label: "Фокус")
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow.opacity(0.85))
                        Text("25м")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Нажмите для старта 25м фокуса или правой кнопкой для выбора пресета")
                .contextMenu {
                    Button("25 мин Фокус (Помодоро)") { timer.start(minutes: 25, label: "Фокус") }
                    Button("15 мин Спринт") { timer.start(minutes: 15, label: "Спринт") }
                    Button("5 мин Перерыв") { timer.start(minutes: 5, label: "Перерыв") }
                    Button("45 мин Глубокая работа") { timer.start(minutes: 45, label: "Работа") }
                    Button("60 мин 1 час") { timer.start(minutes: 60, label: "1 час") }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
