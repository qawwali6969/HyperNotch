import SwiftUI

struct LiveWaveformView: View {
    let isPlaying: Bool
    var barColor: Color = Color.green
    var maxHeight: CGFloat = 14
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: isPlaying ? 0.2 : 10.0)) { timeline in
            let dateVal = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    let offset = Double(index) * 1.8
                    let speed = 7.5 + Double(index % 3) * 2.0
                    let raw = sin(dateVal * speed + offset)
                    let normalized = isPlaying ? (raw * 0.4 + 0.6) : 0.25
                    let barH = maxHeight * CGFloat(normalized)
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor)
                        .frame(width: 2.5, height: max(3, barH))
                        .animation(.easeInOut(duration: 0.2), value: barH)
                }
            }
            .frame(height: maxHeight)
        }
    }
}

struct CompactMusicHUDView: View {
    @ObservedObject var media = MediaManager.shared
    
    var body: some View {
        if media.isPlaying || !media.trackTitle.isEmpty {
            HStack(spacing: 7) {
                // Live Waveform & Player Icon
                LiveWaveformView(
                    isPlaying: media.isPlaying,
                    barColor: media.activeApp == .spotify ? Color.green : Color.pink,
                    maxHeight: 12
                )
                
                // Track & Artist Info
                VStack(alignment: .leading, spacing: 0.5) {
                    Text(media.trackTitle)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    if !media.artist.isEmpty {
                        Text(media.artist)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: 130, alignment: .leading)
                
                // Playback Controls
                HStack(spacing: 3) {
                    Button(action: { media.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { media.togglePlayPause() }) {
                        Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { media.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}
