import Foundation
import AppKit

@MainActor
class UpdateManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = UpdateManager()
    
    @Published var isChecking: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String = ""
    @Published var releaseNotes: String = ""
    @Published var statusMessage: String? = nil
    @Published var errorMessage: String? = nil
    @Published var isUpToDate: Bool = false
    
    private var downloadUrl: URL?
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    
    var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5"
    }
    
    private let repoOwner = "qawwali6969"
    private let repoName = "HyperNotch"
    
    func checkForUpdates(silent: Bool = false) async {
        guard !isChecking && !isDownloading else { return }
        
        isChecking = true
        errorMessage = nil
        if !silent {
            statusMessage = "Проверка обновлений на GitHub..."
        }
        
        let apiUrlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: apiUrlString) else {
            isChecking = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("HyperNotch-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isChecking = false
                if !silent {
                    errorMessage = "Не удалось связаться с GitHub (код \((response as? HTTPURLResponse)?.statusCode ?? 0))"
                }
                return
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                isChecking = false
                return
            }
            
            let body = json["body"] as? String ?? ""
            let assets = json["assets"] as? [[String: Any]] ?? []
            
            // Find ZIP asset
            var zipUrl: URL? = nil
            for asset in assets {
                if let name = asset["name"] as? String, name.hasSuffix(".zip"),
                   let downloadUrlStr = asset["browser_download_url"] as? String,
                   let assetUrl = URL(string: downloadUrlStr) {
                    zipUrl = assetUrl
                    break
                }
            }
            
            let cleanLatest = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let cleanCurrent = currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            
            isChecking = false
            
            if isVersion(cleanLatest, newerThan: cleanCurrent) && zipUrl != nil {
                updateAvailable = true
                latestVersion = tagName
                releaseNotes = body
                downloadUrl = zipUrl
                statusMessage = "Доступно обновление \(tagName)!"
            } else {
                updateAvailable = false
                if !silent {
                    isUpToDate = true
                    statusMessage = "У вас установлена последняя версия (v\(cleanCurrent))"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                        self?.isUpToDate = false
                        self?.statusMessage = nil
                    }
                }
            }
        } catch {
            isChecking = false
            if !silent {
                errorMessage = "Ошибка подключения: \(error.localizedDescription)"
            }
        }
    }
    
    func installUpdate() async {
        guard let url = downloadUrl, !isDownloading else { return }
        
        isDownloading = true
        downloadProgress = 0.05
        statusMessage = "Загрузка обновления..."
        errorMessage = nil
        
        do {
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let tempZipUrl = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                self.downloadContinuation = continuation
                let task = session.downloadTask(with: url)
                task.resume()
            }
            
            statusMessage = "Установка и распаковка..."
            downloadProgress = 0.95
            
            // Unpack in /tmp
            let updateDir = URL(fileURLWithPath: "/tmp/HyperNotchUpdate")
            try? FileManager.default.removeItem(at: updateDir)
            try FileManager.default.createDirectory(at: updateDir, withIntermediateDirectories: true)
            
            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzipProcess.arguments = ["-q", "-o", tempZipUrl.path, "-d", updateDir.path]
            try unzipProcess.run()
            unzipProcess.waitUntilExit()
            
            // Locate unzipped .app
            let contents = try FileManager.default.contentsOfDirectory(at: updateDir, includingPropertiesForKeys: nil)
            guard let newAppUrl = contents.first(where: { $0.pathExtension == "app" }) else {
                throw NSError(domain: "UpdateManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Приложение не найдено в архиве"])
            }
            
            // Determine target installation path
            var targetPath = "/Applications/HyperNotch.app"
            let runningPath = Bundle.main.bundleURL.path
            if runningPath.hasSuffix(".app") && FileManager.default.isWritableFile(atPath: runningPath) {
                targetPath = runningPath
            }
            
            statusMessage = "Перезапуск..."
            downloadProgress = 1.0
            
            // Generate restart shell script
            let currentPid = ProcessInfo.processInfo.processIdentifier
            let scriptContent = """
            #!/bin/bash
            sleep 0.5
            kill -9 \(currentPid) 2>/dev/null || true
            rm -rf "\(targetPath)"
            cp -R "\(newAppUrl.path)" "\(targetPath)"
            xattr -rd com.apple.quarantine "\(targetPath)" 2>/dev/null || true
            open "\(targetPath)"
            rm -rf /tmp/HyperNotchUpdate "\(tempZipUrl.path)" /tmp/hypernotch_relaunch.sh
            """
            
            let scriptUrl = URL(fileURLWithPath: "/tmp/hypernotch_relaunch.sh")
            try scriptContent.write(to: scriptUrl, atomically: true, encoding: .utf8)
            
            let chmodProcess = Process()
            chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodProcess.arguments = ["+x", scriptUrl.path]
            try chmodProcess.run()
            chmodProcess.waitUntilExit()
            
            let restartProcess = Process()
            restartProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            restartProcess.arguments = [scriptUrl.path]
            try restartProcess.run()
            
            NSApplication.shared.terminate(nil)
        } catch {
            isDownloading = false
            statusMessage = nil
            errorMessage = "Ошибка обновления: \(error.localizedDescription)"
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            Task { @MainActor in
                self.downloadProgress = progress * 0.9 // scale to 90%
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let destUrl = URL(fileURLWithPath: "/tmp/HyperNotchUpdate.zip")
        try? FileManager.default.removeItem(at: destUrl)
        do {
            try FileManager.default.moveItem(at: location, to: destUrl)
            Task { @MainActor in
                self.downloadContinuation?.resume(returning: destUrl)
                self.downloadContinuation = nil
            }
        } catch {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }
    
    // Helper: Simple Semantic Version Comparison
    private func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(parts1.count, parts2.count)
        for i in 0..<maxCount {
            let num1 = i < parts1.count ? parts1[i] : 0
            let num2 = i < parts2.count ? parts2[i] : 0
            if num1 > num2 { return true }
            if num1 < num2 { return false }
        }
        return false
    }
}
