import UIKit
import WebKit
import NetworkExtension

class ViewController: UIViewController, WKNavigationDelegate {
    
    var webView: WKWebView!
    var logTextView: UITextView!
    var proxySwitch: UISwitch!
    var cacheSwitch: UISwitch!
    var statusLabel: UILabel!
    var excludeField: UITextField!
    var statsLabel: UILabel!
    var statsTimer: Timer?
    
    let testRules = [
        "Rewrite: example.com -> baidu.com",
        "Rewrite: iana.org -> bing.com",
        "Header: 添加 X-Proxy-Demo + 修改UA",
        "Block: 12个广告追踪域名"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "App-Proxy Demo v2.0"
        setupUI()
        loadWebView()
        log("Demo v2.0 启动完成")
        log("功能：HTTP 302重定向 + 请求头修改 + 域名拦截 + 统计")
    }
    
    func setupUI() {
        let controlView = UIView()
        controlView.backgroundColor = .secondarySystemBackground
        controlView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlView)
        
        // 代理开关
        let proxyLabel = UILabel()
        proxyLabel.text = "代理"
        proxyLabel.font = .systemFont(ofSize: 14)
        proxyLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(proxyLabel)
        
        proxySwitch = UISwitch()
        proxySwitch.addTarget(self, action: #selector(proxySwitchChanged), for: .valueChanged)
        proxySwitch.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(proxySwitch)
        
        // 缓存开关
        let cacheLabel = UILabel()
        cacheLabel.text = "无缓存"
        cacheLabel.font = .systemFont(ofSize: 14)
        cacheLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(cacheLabel)
        
        cacheSwitch = UISwitch()
        cacheSwitch.addTarget(self, action: #selector(cacheSwitchChanged), for: .valueChanged)
        cacheSwitch.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(cacheSwitch)
        
        // 状态标签
        statusLabel = UILabel()
        statusLabel.text = "未启动"
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .systemRed
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(statusLabel)
        
        // 统计面板
        statsLabel = UILabel()
        statsLabel.text = "请求:0 拦截:0 重定向:0 改头:0 排除:0"
        statsLabel.font = .systemFont(ofSize: 11)
        statsLabel.textColor = .secondaryLabel
        statsLabel.numberOfLines = 0
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(statsLabel)
        
        // 排除域名
        let excludeLabel = UILabel()
        excludeLabel.text = "排除:"
        excludeLabel.font = .systemFont(ofSize: 12)
        excludeLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(excludeLabel)
        
        excludeField = UITextField()
        excludeField.text = "github.com,cloudflare.com"
        excludeField.font = .systemFont(ofSize: 12)
        excludeField.borderStyle = .roundedRect
        excludeField.autocapitalizationType = .none
        excludeField.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(excludeField)
        
        // 按钮行1
        let testBtn = UIButton(type: .system)
        testBtn.setTitle("测试example→百度", for: .normal)
        testBtn.titleLabel?.font = .systemFont(ofSize: 12)
        testBtn.addTarget(self, action: #selector(testRewrite), for: .touchUpInside)
        testBtn.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(testBtn)
        
        let testBtn2 = UIButton(type: .system)
        testBtn2.setTitle("测试iana→必应", for: .normal)
        testBtn2.titleLabel?.font = .systemFont(ofSize: 12)
        testBtn2.addTarget(self, action: #selector(testRewrite2), for: .touchUpInside)
        testBtn2.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(testBtn2)
        
        // 按钮行2
        let clearLogBtn = UIButton(type: .system)
        clearLogBtn.setTitle("清空日志", for: .normal)
        clearLogBtn.titleLabel?.font = .systemFont(ofSize: 12)
        clearLogBtn.addTarget(self, action: #selector(clearLog), for: .touchUpInside)
        clearLogBtn.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(clearLogBtn)
        
        let removeVPNBtn = UIButton(type: .system)
        removeVPNBtn.setTitle("删除VPN配置", for: .normal)
        removeVPNBtn.titleLabel?.font = .systemFont(ofSize: 12)
        removeVPNBtn.setTitleColor(.systemRed, for: .normal)
        removeVPNBtn.addTarget(self, action: #selector(removeVPNConfig), for: .touchUpInside)
        removeVPNBtn.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(removeVPNBtn)
        
        // WebView
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        // 日志
        logTextView = UITextView()
        logTextView.isEditable = false
        logTextView.font = .systemFont(ofSize: 10)
        logTextView.backgroundColor = .black
        logTextView.textColor = .green
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logTextView)
        
        NSLayoutConstraint.activate([
            controlView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            controlView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlView.heightAnchor.constraint(equalToConstant: 200),
            
            proxyLabel.topAnchor.constraint(equalTo: controlView.topAnchor, constant: 8),
            proxyLabel.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 12),
            proxySwitch.centerYAnchor.constraint(equalTo: proxyLabel.centerYAnchor),
            proxySwitch.leadingAnchor.constraint(equalTo: proxyLabel.trailingAnchor, constant: 6),
            
            cacheLabel.centerYAnchor.constraint(equalTo: proxyLabel.centerYAnchor),
            cacheLabel.leadingAnchor.constraint(equalTo: proxySwitch.trailingAnchor, constant: 15),
            cacheSwitch.centerYAnchor.constraint(equalTo: proxyLabel.centerYAnchor),
            cacheSwitch.leadingAnchor.constraint(equalTo: cacheLabel.trailingAnchor, constant: 6),
            
            statusLabel.centerYAnchor.constraint(equalTo: proxyLabel.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -12),
            
            statsLabel.topAnchor.constraint(equalTo: proxyLabel.bottomAnchor, constant: 6),
            statsLabel.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 12),
            statsLabel.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -12),
            
            excludeLabel.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 6),
            excludeLabel.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 12),
            excludeField.centerYAnchor.constraint(equalTo: excludeLabel.centerYAnchor),
            excludeField.leadingAnchor.constraint(equalTo: excludeLabel.trailingAnchor, constant: 6),
            excludeField.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -12),
            excludeField.heightAnchor.constraint(equalToConstant: 26),
            
            testBtn.topAnchor.constraint(equalTo: excludeLabel.bottomAnchor, constant: 8),
            testBtn.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 12),
            testBtn2.centerYAnchor.constraint(equalTo: testBtn.centerYAnchor),
            testBtn2.leadingAnchor.constraint(equalTo: testBtn.trailingAnchor, constant: 12),
            
            clearLogBtn.topAnchor.constraint(equalTo: testBtn.bottomAnchor, constant: 4),
            clearLogBtn.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 12),
            removeVPNBtn.centerYAnchor.constraint(equalTo: clearLogBtn.centerYAnchor),
            removeVPNBtn.leadingAnchor.constraint(equalTo: clearLogBtn.trailingAnchor, constant: 12),
            
            webView.topAnchor.constraint(equalTo: controlView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),
            
            logTextView.topAnchor.constraint(equalTo: webView.bottomAnchor),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            logTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func loadWebView() {
        webView.load(URLRequest(url: URL(string: "https://www.example.com")!))
    }
    
    @objc func proxySwitchChanged() {
        if proxySwitch.isOn {
            startProxy()
        } else {
            stopProxy()
        }
    }
    
    @objc func cacheSwitchChanged() {
        if cacheSwitch.isOn {
            webView.configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
            URLCache.shared.removeAllCachedResponses()
            log("无缓存模式开启")
        } else {
            log("无缓存模式关闭")
        }
        webView.reload()
    }
    
    @objc func testRewrite() {
        log("测试: example.com → baidu.com (HTTP 302)")
        let req = URLRequest(url: URL(string: "http://www.example.com")!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        webView.load(req)
    }
    
    @objc func testRewrite2() {
        log("测试: iana.org → bing.com (HTTP 302)")
        let req = URLRequest(url: URL(string: "http://www.iana.org")!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        webView.load(req)
    }
    
    @objc func clearLog() {
        logTextView.text = ""
    }
    
    @objc func removeVPNConfig() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            for manager in managers ?? [] {
                if manager.localizedDescription == "AppProxyDemo" {
                    manager.removeFromPreferences { _ in
                        self?.log("VPN配置已删除")
                        self?.proxySwitch.isOn = false
                        self?.statusLabel.text = "未启动"
                        self?.statusLabel.textColor = .systemRed
                    }
                }
            }
        }
    }
    
    func startProxy() {
        log("正在启动 App-Proxy...")
        statusLabel.text = "启动中"
        statusLabel.textColor = .systemOrange
        
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                self?.log("加载失败: \(error.localizedDescription)")
                self?.statusLabel.text = "失败"
                self?.statusLabel.textColor = .systemRed
                self?.proxySwitch.isOn = false
                return
            }
            
            let manager: NETunnelProviderManager
            if let existing = managers?.first(where: { $0.localizedDescription == "AppProxyDemo" }) {
                manager = existing
            } else {
                manager = NETunnelProviderManager()
                manager.localizedDescription = "AppProxyDemo"
            }
            
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = "com.demo.AppProxyDemo.AppProxyExtension"
            proto.serverAddress = "127.0.0.1"
            proto.providerConfiguration = [
                "excludeDomains": self?.excludeField.text ?? "",
                "rules": self?.testRules.joined(separator: "|") ?? ""
            ]
            manager.protocolConfiguration = proto
            manager.isEnabled = true
            
            manager.saveToPreferences { error in
                if let error = error {
                    self?.log("保存失败: \(error.localizedDescription)")
                    self?.statusLabel.text = "失败"
                    self?.statusLabel.textColor = .systemRed
                    self?.proxySwitch.isOn = false
                    return
                }
                manager.loadFromPreferences { _ in
                    do {
                        try manager.connection.startVPNTunnel()
                        self?.log("✅ App-Proxy 启动成功")
                        self?.statusLabel.text = "运行中"
                        self?.statusLabel.textColor = .systemGreen
                        self?.startStatsTimer()
                        self?.webView.reload()
                    } catch {
                        self?.log("启动失败: \(error.localizedDescription)")
                        self?.statusLabel.text = "失败"
                        self?.statusLabel.textColor = .systemRed
                        self?.proxySwitch.isOn = false
                    }
                }
            }
        }
    }
    
    func stopProxy() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            if let manager = managers?.first(where: { $0.localizedDescription == "AppProxyDemo" }) {
                manager.connection.stopVPNTunnel()
                self?.log("App-Proxy 已停止")
                self?.statusLabel.text = "已停止"
                self?.statusLabel.textColor = .systemRed
                self?.stopStatsTimer()
            }
        }
    }
    
    func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }
    
    func updateStats() {
        let defaults = UserDefaults(suiteName: "group.com.demo.AppProxyDemo")
        let total = defaults?.integer(forKey: "totalRequests") ?? 0
        let blocked = defaults?.integer(forKey: "blocked") ?? 0
        let redirected = defaults?.integer(forKey: "redirected") ?? 0
        let modified = defaults?.integer(forKey: "headerModified") ?? 0
        let excluded = defaults?.integer(forKey: "excluded") ?? 0
        statsLabel.text = "总请求:\(total) 拦截:\(blocked) 重定向:\(redirected) 改头:\(modified) 排除:\(excluded)"
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url {
            log("→ \(url.absoluteString)")
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            log("✓ \(url.absoluteString)")
            if url.absoluteString.contains("baidu.com") {
                log("🎉 Rewrite成功: example.com → baidu.com")
            }
            if url.absoluteString.contains("bing.com") {
                log("🎉 Rewrite成功: iana.org → bing.com")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log("✗ \(error.localizedDescription)")
    }
    
    func log(_ message: String) {
        DispatchQueue.main.async {
            let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.logTextView.text += "[\(ts)] \(message)\n"
            let range = NSRange(location: self.logTextView.text.count - 1, length: 1)
            self.logTextView.scrollRangeToVisible(range)
        }
    }
}
