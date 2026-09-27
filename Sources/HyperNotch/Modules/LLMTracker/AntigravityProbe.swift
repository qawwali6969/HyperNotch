import Foundation
import Darwin

enum AntigravityProbe {
    struct Bucket {
        let bucketId: String
        let displayName: String
        let remainingFraction: Double // 0.0 ... 1.0
        let resetTime: Date?
        let window: String
    }
    
    struct Group {
        let displayName: String // e.g. "Gemini Models", "Claude and GPT models"
        let buckets: [Bucket]
    }
    
    static func listeningTCPPorts(pid: Int32) -> [Int] {
        let lsofPipe = Pipe()
        let lsofProc = Process()
        lsofProc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsofProc.arguments = ["-a", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN", "-F", "n"]
        lsofProc.standardOutput = lsofPipe
        if (try? lsofProc.run()) != nil {
            let data = lsofPipe.fileHandleForReading.readDataToEndOfFile()
            lsofProc.waitUntilExit()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                var ports: Set<Int> = []
                for line in output.components(separatedBy: .newlines) {
                    if line.hasPrefix("n") {
                        let parts = line.dropFirst().components(separatedBy: ":")
                        if let last = parts.last, let port = Int(last), port > 0 {
                            ports.insert(port)
                        }
                    }
                }
                if !ports.isEmpty {
                    return ports.sorted()
                }
            }
        }
        
        let requiredBytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard requiredBytes > 0 else { return [] }
        let descriptorStride = MemoryLayout<proc_fdinfo>.stride
        var descriptors = [proc_fdinfo](
            repeating: proc_fdinfo(),
            count: Int(requiredBytes) / descriptorStride + 8
        )
        let actualBytes = descriptors.withUnsafeMutableBytes { buffer in
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buffer.baseAddress, Int32(buffer.count))
        }
        guard actualBytes > 0 else { return [] }
        
        var ports: Set<Int> = []
        for descriptor in descriptors.prefix(Int(actualBytes) / descriptorStride)
            where descriptor.proc_fdtype == PROX_FDTYPE_SOCKET {
            var info = socket_fdinfo()
            let byteCount = proc_pidfdinfo(
                pid,
                descriptor.proc_fd,
                PROC_PIDFDSOCKETINFO,
                &info,
                Int32(MemoryLayout<socket_fdinfo>.size)
            )
            guard byteCount == MemoryLayout<socket_fdinfo>.size,
                  info.psi.soi_kind == SOCKINFO_TCP,
                  info.psi.soi_proto.pri_tcp.tcpsi_state == TSI_S_LISTEN
            else { continue }
            let networkPort = UInt16(truncatingIfNeeded: info.psi.soi_proto.pri_tcp.tcpsi_ini.insi_lport)
            ports.insert(Int(UInt16(bigEndian: networkPort)))
        }
        return ports.sorted()
    }
    
    static func probeLocalGroups() async -> [Group]? {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-ax", "-o", "pid,command"]
        proc.standardOutput = pipe
        do {
            try proc.run()
        } catch {
            return nil
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        
        var targetPID: Int32? = nil
        var targetToken: String = ""
        
        for line in output.components(separatedBy: .newlines) {
            guard line.contains("language_server") && line.contains("--csrf_token") else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let firstSpace = trimmed.firstIndex(of: " ") else { continue }
            let pidStr = String(trimmed[..<firstSpace])
            guard let pid = Int32(pidStr), pid > 0 else { continue }
            
            guard let tokenRange = line.range(of: "--csrf_token ") else { continue }
            let afterToken = String(line[tokenRange.upperBound...])
            let token = afterToken.components(separatedBy: " ").first ?? ""
            guard !token.isEmpty else { continue }
            
            targetPID = pid
            targetToken = token
            break
        }
        
        guard let pid = targetPID, !targetToken.isEmpty else { return nil }
        
        let ports = listeningTCPPorts(pid: pid)
        guard !ports.isEmpty else { return nil }
        
        let session = URLSession(configuration: .ephemeral, delegate: AntigravityLocalhostSessionDelegate.shared, delegateQueue: nil)
        
        for port in ports {
            guard let url = URL(string: "https://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
            req.setValue(targetToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
            req.httpBody = "{\"forceRefresh\": true}".data(using: .utf8)
            req.timeoutInterval = 2.5
            
            var responseData: Data? = nil
            do {
                let (data, resp) = try await session.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    responseData = data
                }
            } catch {
                // If URLSession TLS check fails, run curl -k fallback
                let curlPipe = Pipe()
                let curlProc = Process()
                curlProc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                curlProc.arguments = [
                    "-k", "-s", "-m", "3", "-X", "POST",
                    "https://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary",
                    "-H", "Content-Type: application/json",
                    "-H", "Connect-Protocol-Version: 1",
                    "-H", "X-Codeium-Csrf-Token: \(targetToken)",
                    "-d", "{\"forceRefresh\": true}"
                ]
                curlProc.standardOutput = curlPipe
                if (try? curlProc.run()) != nil {
                    let cData = curlPipe.fileHandleForReading.readDataToEndOfFile()
                    curlProc.waitUntilExit()
                    if !cData.isEmpty {
                        responseData = cData
                    }
                }
            }
            
            guard let respData = responseData else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let responseDict = json["response"] as? [String: Any],
                  let groupsArr = responseDict["groups"] as? [[String: Any]] else {
                continue
            }
            
            var parsedGroups: [Group] = []
            for g in groupsArr {
                let groupTitle = g["displayName"] as? String ?? "Models"
                var parsedBuckets: [Bucket] = []
                
                if let bucketsArr = g["buckets"] as? [[String: Any]] {
                    for b in bucketsArr {
                        let bId = b["bucketId"] as? String ?? ""
                        let bName = b["displayName"] as? String ?? "Limit Remaining"
                        var fraction = 1.0
                        if let fStr = b["remainingFraction"] as? String, let d = Double(fStr) {
                            fraction = d
                        } else if let fNum = b["remainingFraction"] as? Double {
                            fraction = fNum
                        }
                        
                        var rDate: Date? = nil
                        if let rStr = b["resetTime"] as? String {
                            let iso = ISO8601DateFormatter()
                            rDate = iso.date(from: rStr)
                        }
                        let wStr = b["window"] as? String ?? ""
                        
                        parsedBuckets.append(Bucket(
                            bucketId: bId,
                            displayName: bName,
                            remainingFraction: max(0.0, min(1.0, fraction)),
                            resetTime: rDate,
                            window: wStr
                        ))
                    }
                }
                parsedGroups.append(Group(displayName: groupTitle, buckets: parsedBuckets))
            }
            
            return parsedGroups
        }
        
        return nil
    }
}

final class AntigravityLocalhostSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = AntigravityLocalhostSessionDelegate()
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if let trust = challenge.protectionSpace.serverTrust {
            return (.useCredential, URLCredential(trust: trust))
        }
        return (.performDefaultHandling, nil)
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if let trust = challenge.protectionSpace.serverTrust {
            return (.useCredential, URLCredential(trust: trust))
        }
        return (.performDefaultHandling, nil)
    }
}
