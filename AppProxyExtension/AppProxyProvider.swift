import NetworkExtension

class AppProxyProvider: NEAppProxyProvider {
    
    var excludeDomains: [String] = []
    var rules: [String] = []
    
    override func startProxy(options: [String : Any]? = nil) async throws {
        if let exclude = options?["excludeDomains"] as? String {
            excludeDomains = exclude.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        if let rulesStr = options?["rules"] as? String {
            rules = rulesStr.components(separatedBy: "|")
        }
        NSLog("[AppProxy] 代理启动，排除域名: \(excludeDomains)，规则: \(rules.count)条")
    }
    
    override func stopProxy(with reason: NEProviderStopReason) async {
        NSLog("[AppProxy] 代理停止，原因: \(reason.rawValue)")
    }
    
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let tcpFlow = flow as? NEAppProxyTCPFlow else {
            return false
        }
        
        let remoteHost = flow.remoteHostname ?? ""
        // 从remoteEndpoint获取端口
        var remotePort: UInt16 = 80
        if let endpoint = flow.remoteEndpoint as? NWHostEndpoint {
            remotePort = UInt16(endpoint.port) ?? 80
        }
        
        NSLog("[AppProxy] TCP流: \(remoteHost):\(remotePort)")
        
        if isExcluded(remoteHost) {
            NSLog("[AppProxy] 域名排除，直接放行: \(remoteHost)")
            return false
        }
        
        if isBlocked(remoteHost) {
            NSLog("[AppProxy] 域名拦截，断开连接: \(remoteHost)")
            tcpFlow.closeReadWithError(nil)
            tcpFlow.closeWriteWithError(nil)
            return true
        }
        
        if let redirectURL = checkRewrite(remoteHost) {
            NSLog("[AppProxy] Rewrite命中: \(remoteHost) -> \(redirectURL)")
        }
        
        let endpoint = NWHostEndpoint(hostname: remoteHost, port: "\(remotePort)")
        let connection = self.createTCPConnection(to: endpoint, enableTLS: remotePort == 443, tlsParameters: nil, delegate: nil)
        
        tcpFlow.readData { [weak self] data, error in
            guard let data = data, !data.isEmpty else {
                if let error = error {
                    NSLog("[AppProxy] 读取客户端数据失败: \(error.localizedDescription)")
                }
                return
            }
            
            var modifiedData = data
            
            if remotePort == 80, let requestStr = String(data: data, encoding: .utf8),
               requestStr.hasPrefix("GET") || requestStr.hasPrefix("POST") {
                modifiedData = self?.addCustomHeaders(to: requestStr) ?? data
                NSLog("[AppProxy] HTTP请求已修改，添加自定义头")
            }
            
            connection.write(modifiedData) { error in
                if let error = error {
                    NSLog("[AppProxy] 写入远程失败: \(error.localizedDescription)")
                }
            }
            
            self?.pipeFlow(tcpFlow, to: connection)
        }
        
        return true
    }
    
    override func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {
        NSLog("[AppProxy] UDP流: \(remoteEndpoint)")
        return false
    }
    
    func isExcluded(_ host: String) -> Bool {
        for domain in excludeDomains where !domain.isEmpty {
            if host.contains(domain) {
                return true
            }
        }
        return false
    }
    
    func isBlocked(_ host: String) -> Bool {
        let blockedDomains = ["doubleclick.net", "googlesyndication.com", "googleadservices.com"]
        for domain in blockedDomains {
            if host.contains(domain) {
                return true
            }
        }
        return false
    }
    
    func checkRewrite(_ host: String) -> String? {
        if host.contains("example.com") {
            return "https://www.baidu.com"
        }
        return nil
    }
    
    func addCustomHeaders(to request: String) -> Data {
        var modified = request
        modified = modified.replacingOccurrences(of: "\r\n\r\n", with: "\r\nX-Proxy-Demo: Test123\r\n\r\n")
        modified = modified.replacingOccurrences(of: "User-Agent: ", with: "User-Agent: AppProxyDemo/1.0 ")
        return modified.data(using: .utf8) ?? request.data(using: .utf8)!
    }
    
    func pipeFlow(_ flow: NEAppProxyTCPFlow, to connection: NWTCPConnection) {
        flow.readData { data, error in
            guard let data = data, !data.isEmpty else { return }
            connection.write(data) { _ in }
            self.pipeFlow(flow, to: connection)
        }
        
        connection.readMinimumLength(1, maximumLength: 65535) { data, _ in
            guard let data = data, !data.isEmpty else { return }
            flow.write(data) { _ in }
            self.pipeFlow(flow, to: connection)
        }
    }
}
