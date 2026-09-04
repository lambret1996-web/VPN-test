import NetworkExtension

class AppProxyProvider: NEAppProxyProvider {
    
    var excludeDomains: [String] = []
    var rules: [String] = []
    
    override func startProxy(options: [String : Any]? = nil) async throws {
        // 读取主App下发的配置
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
    
    // 处理TCP流量
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let tcpFlow = flow as? NEAppProxyTCPFlow else {
            return false
        }
        
        let remoteHost = flow.remoteHostname ?? ""
        let remotePort = flow.remotePort
        
        NSLog("[AppProxy] TCP流: \(remoteHost):\(remotePort)")
        
        // 检查排除域名
        if isExcluded(remoteHost) {
            NSLog("[AppProxy] 域名排除，直接放行: \(remoteHost)")
            return false // 返回false表示不处理，系统直接连接
        }
        
        // 检查拦截域名
        if isBlocked(remoteHost) {
            NSLog("[AppProxy] 域名拦截，断开连接: \(remoteHost)")
            tcpFlow.closeWriteAndRead()
            return true
        }
        
        // 检查Rewrite规则
        if let redirectURL = checkRewrite(remoteHost) {
            NSLog("[AppProxy] Rewrite命中: \(remoteHost) -> \(redirectURL)")
            // 对于HTTPS，无法简单重定向URL，只能记录
            // 对于HTTP，可以在handleNewFlow中处理
        }
        
        // 正常代理：建立到目标的连接
        let endpoint = NWHostEndpoint(hostname: remoteHost, port: "\(remotePort)")
        let connection = self.createTCPConnection(to: endpoint, enableTLS: remotePort == 443, tlsParameters: nil, delegate: nil)
        
        // 读取客户端数据，添加自定义请求头
        tcpFlow.readData { [weak self] data, error in
            guard let data = data, !data.isEmpty else {
                if let error = error {
                    NSLog("[AppProxy] 读取客户端数据失败: \(error.localizedDescription)")
                }
                return
            }
            
            var modifiedData = data
            
            // 如果是HTTP请求，添加自定义头
            if remotePort == 80, let requestStr = String(data: data, encoding: .utf8),
               requestStr.hasPrefix("GET") || requestStr.hasPrefix("POST") {
                modifiedData = self?.addCustomHeaders(to: requestStr, originalHost: remoteHost) ?? data
                NSLog("[AppProxy] HTTP请求已修改，添加自定义头")
            }
            
            // 写入到远程连接
            connection.write(modifiedData) { error in
                if let error = error {
                    NSLog("[AppProxy] 写入远程失败: \(error.localizedDescription)")
                }
            }
            
            // 建立双向数据转发
            self?.pipeFlow(tcpFlow, to: connection)
        }
        
        return true
    }
    
    // 处理UDP流量
    override func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {
        NSLog("[AppProxy] UDP流: \(remoteEndpoint)")
        return false // UDP直接放行
    }
    
    // MARK: - 规则处理
    
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
    
    func addCustomHeaders(to request: String, originalHost: String) -> Data {
        var modified = request
        // 添加自定义头
        modified = modified.replacingOccurrences(of: "\r\n\r\n", with: "\r\nX-Proxy-Demo: Test123\r\n\r\n")
        // 修改User-Agent
        modified = modified.replacingOccurrences(of: "User-Agent: ", with: "User-Agent: AppProxyDemo/1.0 ")
        return modified.data(using: .utf8) ?? request.data(using: .utf8)!
    }
    
    // MARK: - 数据转发
    
    func pipeFlow(_ flow: NEAppProxyTCPFlow, to connection: NWTCPConnection) {
        // 客户端 -> 远程
        flow.readData { data, error in
            guard let data = data, !data.isEmpty else { return }
            connection.write(data) { _ in }
            self.pipeFlow(flow, to: connection)
        }
        
        // 远程 -> 客户端
        connection.readMinimumLength(1, maximumLength: 65535) { data, _ in
            guard let data = data, !data.isEmpty else { return }
            flow.write(data) { _ in }
            self.pipeFlow(flow, to: connection)
        }
    }
}
