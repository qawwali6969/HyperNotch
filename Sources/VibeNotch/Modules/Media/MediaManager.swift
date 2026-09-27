import Foundation
import AppKit
import Combine

enum ActivePlayerApp: String {
    case spotify = "Spotify"
    case appleMusic = "Music"
    
    var iconName: String {
        switch self {
        case .spotify: return "music.note"
        case .appleMusic: return "apple.logo"
        }
    }
}

@MainActor
class MediaManager: ObservableObject {
    static let shared = MediaManager()
    
    @Published var isPlaying: Bool = false
    @Published var trackTitle: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var activeApp: ActivePlayerApp? = nil
    
    private var timer: AnyCancellable?
    
    init() {
        setupDistributedNotifications()
        refreshNowPlaying()
        
        // Polling check every 4 seconds to keep state in sync
        timer = Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshNowPlaying()
            }
    }
    
    private func setupDistributedNotifications() {
        let dnc = DistributedNotificationCenter.default()
        
        // Spotify notification
        dnc.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo {
                let state = (userInfo["Player State"] as? String)?.lowercased() ?? ""
                let isPlay = (state == "playing" || state == "kpsp")
                let title = (userInfo["Name"] as? String) ?? ""
                let artist = (userInfo["Artist"] as? String) ?? ""
                let album = (userInfo["Album"] as? String) ?? ""
                
                Task { @MainActor in
                    MediaManager.shared.update(isPlaying: isPlay, title: title, artist: artist, album: album, app: .spotify)
                }
            }
        }
        
        // Apple Music notification
        dnc.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo {
                let state = (userInfo["Player State"] as? String)?.lowercased() ?? ""
                let isPlay = (state == "playing")
                let title = (userInfo["Name"] as? String) ?? ""
                let artist = (userInfo["Artist"] as? String) ?? ""
                let album = (userInfo["Album"] as? String) ?? ""
                
                Task { @MainActor in
                    MediaManager.shared.update(isPlaying: isPlay, title: title, artist: artist, album: album, app: .appleMusic)
                }
            }
        }
    }
    
    func refreshNowPlaying() {
        let spotifyRunning = isAppRunning("Spotify")
        let musicRunning = isAppRunning("Music")
        
        if !spotifyRunning && !musicRunning {
            if activeApp != nil {
                isPlaying = false
                activeApp = nil
                trackTitle = ""
                artist = ""
            }
            return
        }
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // First check if Spotify is running
            if spotifyRunning {
                let script = """
                tell application "Spotify"
                    if player state is playing then
                        return "playing|||" & (name of current track) & "|||" & (artist of current track) & "|||" & (album of current track)
                    else if player state is paused then
                        return "paused|||" & (name of current track) & "|||" & (artist of current track) & "|||" & (album of current track)
                    end if
                    return "stopped||||||"
                end tell
                """
                if let res = self.runAppleScript(script), !res.isEmpty, !res.hasPrefix("stopped") {
                    let parts = res.components(separatedBy: "|||")
                    let isPlay = parts[0] == "playing"
                    let title = parts.count > 1 ? parts[1] : ""
                    let artist = parts.count > 2 ? parts[2] : ""
                    let album = parts.count > 3 ? parts[3] : ""
                    
                    self.update(isPlaying: isPlay, title: title, artist: artist, album: album, app: .spotify)
                    return
                }
            }
            
            // Check Apple Music
            if musicRunning {
                let script = """
                tell application "Music"
                    if player state is playing then
                        return "playing|||" & (name of current track) & "|||" & (artist of current track) & "|||" & (album of current track)
                    else if player state is paused then
                        return "paused|||" & (name of current track) & "|||" & (artist of current track) & "|||" & (album of current track)
                    end if
                    return "stopped||||||"
                end tell
                """
                if let res = self.runAppleScript(script), !res.isEmpty, !res.hasPrefix("stopped") {
                    let parts = res.components(separatedBy: "|||")
                    let isPlay = parts[0] == "playing"
                    let title = parts.count > 1 ? parts[1] : ""
                    let artist = parts.count > 2 ? parts[2] : ""
                    let album = parts.count > 3 ? parts[3] : ""
                    
                    self.update(isPlaying: isPlay, title: title, artist: artist, album: album, app: .appleMusic)
                    return
                }
            }
            
            if self.isPlaying {
                self.isPlaying = false
            }
        }
    }
    
    func update(isPlaying: Bool, title: String, artist: String, album: String, app: ActivePlayerApp) {
        self.isPlaying = isPlaying
        self.trackTitle = title
        self.artist = artist
        self.album = album
        self.activeApp = app
    }
    
    func togglePlayPause() {
        guard let app = activeApp ?? (isAppRunning("Spotify") ? .spotify : (isAppRunning("Music") ? .appleMusic : nil)) else { return }
        let appName = app.rawValue
        let script = "tell application \"\(appName)\" to playpause"
        _ = runAppleScript(script)
        isPlaying.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshNowPlaying()
        }
    }
    
    func nextTrack() {
        guard let app = activeApp ?? (isAppRunning("Spotify") ? .spotify : (isAppRunning("Music") ? .appleMusic : nil)) else { return }
        let appName = app.rawValue
        let script = "tell application \"\(appName)\" to next track"
        _ = runAppleScript(script)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshNowPlaying()
        }
    }
    
    func previousTrack() {
        guard let app = activeApp ?? (isAppRunning("Spotify") ? .spotify : (isAppRunning("Music") ? .appleMusic : nil)) else { return }
        let appName = app.rawValue
        let script = "tell application \"\(appName)\" to previous track"
        _ = runAppleScript(script)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshNowPlaying()
        }
    }
    
    private nonisolated func isAppRunning(_ name: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains { app in
            app.localizedName == name
        }
    }
    
    private nonisolated func runAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        if let scriptObj = NSAppleScript(source: script) {
            let output = scriptObj.executeAndReturnError(&error)
            if error == nil {
                return output.stringValue
            }
        }
        return nil
    }
}
