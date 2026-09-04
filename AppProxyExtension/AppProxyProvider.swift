import NetworkExtension

class AppProxyProvider: NEAppProxyProvider {
    
    var excludeDomains: [String] = []
    var rules: [String] = []
    
    // 请求统计
    struct Stats {
        static var totalRequests = 0
        static var blocked = 0
        static var redirected = 0
        static var headerModified = 0
        static var excluded = 0
    }
    
    override func startProxy(options: [String : Any]? = nil) async throws {
        if let exclude = options?["excludeDomains"] as? String {
            excludeDomains = exclude.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        if let rulesStr = options?["rules"] as? String {
            rules = rulesStr.components(separatedBy: "|")
        }
        Stats.totalRequests = 0
        Stats.blocked = 0
        Stats.redirected = 0
        Stats.headerModified = 0
        Stats.excluded = 0
        saveStats()
        NSLog("[AppProxy] 代理启动v2，排除域名: \(excludeDomains)")
    }
    
    override func stopProxy(with reason: NEProviderStopReason) async {
        NSLog("[AppProxy] 代理停止，原因: \(reason.rawValue)")
    }
    
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let tcpFlow = flow as? NEAppProxyTCPFlow else {
            return false
        }
        
        let remoteHost = flow.remoteHostname ?? ""
        Stats.totalRequests += 1
        saveStats()
        
        NSLog("[AppProxy] 请求[\(Stats.totalRequests)]: \(remoteHost)")
        
        if isExcluded(remoteHost) {
            Stats.excluded += 1
            saveStats()
            return false
        }
        
        if isBlocked(remoteHost) {
            Stats.blocked += 1
            saveStats()
            NSLog("[AppProxy] 拦截: \(remoteHost)")
            tcpFlow.closeReadWithError(nil)
            tcpFlow.closeWriteWithError(nil)
            return true
        }
        
        let rewriteTarget = checkRewrite(remoteHost)
        let targetHost = rewriteTarget != nil ? extractHost(from: rewriteTarget!) : remoteHost
        let targetPort: UInt16 = rewriteTarget != nil ? (rewriteTarget!.hasPrefix("https") ? 443 : 80) : 443
        
        let endpoint = NWHostEndpoint(hostname: targetHost, port: "\(targetPort)")
        let connection = self.createTCPConnection(to: endpoint, enableTLS: targetPort == 443, tlsParameters: nil, delegate: nil)
        
        tcpFlow.readData { [weak self] data, error in
            guard let self = self, let data = data, !data.isEmpty else { return }
            
            var outputData = data
            
            if let requestStr = String(data: data, encoding: .utf8),
               requestStr.hasPrefix("GET") || requestStr.hasPrefix("POST") || requestStr.hasPrefix("HEAD") {
                
                if let target = rewriteTarget {
                    Stats.redirected += 1
                    self.saveStats()
                    NSLog("[AppProxy] 302重定向: \(remoteHost) -> \(target)")
                    let resp = "HTTP/1.1 302 Found\r\nLocation: \(target)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    tcpFlow.write(resp.data(using: .utf8)!) { _ in
                        tcpFlow.closeReadWithError(nil)
                        tcpFlow.closeWriteWithError(nil)
                    }
                    connection.cancel()
                    return
                }
                
                outputData = self.modifyHTTPHeaders(requestStr)
                Stats.headerModified += 1
                self.saveStats()
            }
            
            connection.write(outputData) { _ in }
            self.forwardFlow(tcpFlow, connection: connection)
        }
        
        return true
    }
    
    override func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {
        return false
    }
    
    func forwardFlow(_ flow: NEAppProxyTCPFlow, connection: NWTCPConnection) {
        var clientClosed = false
        var serverClosed = false
        
        func readClient() {
            guard !clientClosed else { return }
            flow.readData { data, _ in
                if let data = data, !data.isEmpty {
                    connection.write(data) { _ in }
                    readClient()
                } else {
                    clientClosed = true
                    connection.cancel()
                    if serverClosed { flow.closeReadWithError(nil) }
                }
            }
        }
        
        func readServer() {
            guard !serverClosed else { return }
            connection.readMinimumLength(1, maximumLength: 65535) { data, _ in
                if let data = data, !data.isEmpty {
                    flow.write(data) { _ in }
                    readServer()
                } else {
                    serverClosed = true
                    flow.closeWriteWithError(nil)
                    if clientClosed { connection.cancel() }
                }
            }
        }
        
        readClient()
        readServer()
    }
    
    func isExcluded(_ host: String) -> Bool {
        for domain in excludeDomains where !domain.isEmpty {
            if host.contains(domain) { return true }
        }
        return false
    }
    
    func isBlocked(_ host: String) -> Bool {
        let blocked = [
            "doubleclick.net", "googlesyndication.com", "googleadservices.com",
            "google-analytics.com", "googletagmanager.com", "facebook.net",
            "scorecardresearch.com", "quantserve.com", "adnxs.com",
            "criteo.com", "taboola.com", "outbrain.com"
        ]
        for domain in blocked {
            if host.contains(domain) { return true }
        }
        return false
    }
    
    func checkRewrite(_ host: String) -> String? {
        if host.contains("example.com") { return "https://www.baidu.com" }
        if host.contains("iana.org") { return "https://www.bing.com" }
        return nil
    }
    
    func modifyHTTPHeaders(_ request: String) -> Data {
        var modified = request
        if !modified.contains("X-Proxy-Demo") {
            modified = modified.replacingOccurrences(of: "\r\n\r\n", with: "\r\nX-Proxy-Demo: AppProxyDemo-v2\r\n\r\n")
        }
        if let uaRange = modified.range(of: "User-Agent: ") {
            let endOfLine = modified[uaRange.upperBound...].firstIndex(of: "\r\n") ?? modified.endIndex
            modified.replaceSubrange(uaRange.upperBound..<endOfLine, with: "AppProxyDemo/2.0 (iPhone; iOS 17.0)")
        }
        return modified.data(using: .utf8) ?? request.data(using: .utf8)!
    }
    
    func extractHost(from url: String) -> String {
        if let range = url.range(of: "://") {
            let after = url[range.upperBound...]
            if let slash = after.range(of: "/") {
                return String(after[..<slash.lowerBound])
            }
            return String(after)
        }
        return url
    }
    
    func saveStats() {
        let defaults = UserDefaults(suiteName: "group.com.demo.AppProxyDemo")
        defaults?.set(Stats.totalRequests, forKey: "totalRequests")
        defaults?.set(Stats.blocked, forKey: "blocked")
        defaults?.set(Stats.redirected, forKey: "redirected")
        defaults?.set(Stats.headerModified, forKey: "headerModified")
        defaults?.set(Stats.excluded, forKey: "excluded")
    }
}
