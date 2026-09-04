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
    
    // App Proxy 管理器
    var proxyManager: NEAppProxyProviderManager?
    
    // 测试规则（硬编码）
    let testRules = [
        "Rewrite: example.com -> baidu.com",
        "Header: 添加 X-Proxy-Demo: Test123",
        "Block: doubleclick.net"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "App-Proxy Demo"
        setupUI()
        loadWebView()
        log("Demo 启动完成")
        log("测试规则已加载：\(testRules.count) 条")
    }
    
    func setupUI() {
        // 顶部控制栏
        let controlView = UIView()
        controlView.backgroundColor = .secondarySystemBackground
        controlView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlView)
        
        // 代理开关
        let proxyLabel = UILabel()
        proxyLabel.text = "App-Proxy 代理"
        proxyLabel.font = .systemFont(ofSize: 14)
        proxyLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(proxyLabel)
        
        proxySwitch = UISwitch()
        proxySwitch.isOn = false
        proxySwitch.addTarget(self, action: #selector(proxySwitchChanged), for: .valueChanged)
        proxySwitch.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(proxySwitch)
        
        // 缓存开关
        let cacheLabel = UILabel()
        cacheLabel.text = "无缓存模式"
        cacheLabel.font = .systemFont(ofSize: 14)
        cacheLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(cacheLabel)
        
        cacheSwitch = UISwitch()
        cacheSwitch.isOn = false
        cacheSwitch.addTarget(self, action: #selector(cacheSwitchChanged), for: .valueChanged)
        cacheSwitch.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(cacheSwitch)
        
        // 状态标签
        statusLabel = UILabel()
        statusLabel.text = "代理：未启动"
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabel
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(statusLabel)
        
        // 域名排除输入
        let excludeLabel = UILabel()
        excludeLabel.text = "排除域名(逗号分隔):"
        excludeLabel.font = .systemFont(ofSize: 12)
        excludeLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(excludeLabel)
        
        excludeField = UITextField()
        excludeField.placeholder = "github.com,cloudflare.com"
        excludeField.font = .systemFont(ofSize: 12)
        excludeField.borderStyle = .roundedRect
        excludeField.autocapitalizationType = .none
        excludeField.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(excludeField)
        
        // 测试按钮
        let testBtn = UIButton(type: .system)
        testBtn.setTitle("测试 Rewrite (访问example.com)", for: .normal)
        testBtn.addTarget(self, action: #selector(testRewrite), for: .touchUpInside)
        testBtn.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(testBtn)
        
        let clearBtn = UIButton(type: .system)
        clearBtn.setTitle("清空日志", for: .normal)
        clearBtn.addTarget(self, action: #selector(clearLog), for: .touchUpInside)
        clearBtn.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(clearBtn)
        
        // WebView
        let webConfig = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfig)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        // 日志面板
        logTextView = UITextView()
        logTextView.isEditable = false
        logTextView.font = .systemFont(ofSize: 11)
        logTextView.backgroundColor = .black
        logTextView.textColor = .green
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logTextView)
        
        NSLayoutConstraint.activate([
            controlView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            controlView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlView.heightAnchor.constraint(equalToConstant: 180),
            
            proxyLabel.topAnchor.constraint(equalTo: controlView.topAnchor, constant: 10),
            proxyLabel.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 15),
            proxySwitch.centerYAnchor.constraint(equalTo: proxyLabel.centerYAnchor),
            proxySwitch.leadingAnchor.constraint(equalTo: proxyLabel.trailingAnchor, constant: 10),
            
            cacheLabel.centerYAnchor.constraint(equalTo: proxyLabel.centerYAnchor),
            cacheLabel.leadingAnchor.constraint(equalTo: proxySwitch.trailingAnchor, constant: 20),
            cacheSwitch.centerYAnchor.constraint(equalTo: proxyLabel.centerYAnchor),
            cacheSwitch.leadingAnchor.constraint(equalTo: cacheLabel.trailingAnchor, constant: 10),
            
            statusLabel.topAnchor.constraint(equalTo: proxyLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 15),
            
            excludeLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            excludeLabel.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 15),
            excludeField.centerYAnchor.constraint(equalTo: excludeLabel.centerYAnchor),
            excludeField.leadingAnchor.constraint(equalTo: excludeLabel.trailingAnchor, constant: 8),
            excludeField.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -15),
            excludeField.heightAnchor.constraint(equalToConstant: 28),
            
            testBtn.topAnchor.constraint(equalTo: excludeLabel.bottomAnchor, constant: 10),
            testBtn.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 15),
            clearBtn.centerYAnchor.constraint(equalTo: testBtn.centerYAnchor),
            clearBtn.leadingAnchor.constraint(equalTo: testBtn.trailingAnchor, constant: 20),
            
            webView.topAnchor.constraint(equalTo: controlView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45),
            
            logTextView.topAnchor.constraint(equalTo: webView.bottomAnchor),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            logTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func loadWebView() {
        if let url = URL(string: "https://www.example.com") {
            webView.load(URLRequest(url: url))
        }
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
            // 禁用缓存
            webView.configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
            URLCache.shared.removeAllCachedResponses()
            log("无缓存模式：已开启，所有请求强制走网络")
        } else {
            log("无缓存模式：已关闭，恢复正常缓存")
        }
        webView.reload()
    }
    
    @objc func testRewrite() {
        log("测试 Rewrite：访问 example.com，预期跳转到 baidu.com")
        if let url = URL(string: "https://www.example.com") {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
            webView.load(request)
        }
    }
    
    @objc func clearLog() {
        logTextView.text = ""
    }
    
    func startProxy() {
        log("正在启动 App-Proxy...")
        statusLabel.text = "代理：启动中..."
        
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                self?.log("加载代理配置失败: \(error.localizedDescription)")
                self?.statusLabel.text = "代理：启动失败"
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
                    self?.log("保存代理配置失败: \(error.localizedDescription)")
                    self?.statusLabel.text = "代理：启动失败"
                    self?.proxySwitch.isOn = false
                    return
                }
                manager.loadFromPreferences { _ in
                    do {
                        try manager.connection.startVPNTunnel()
                        self?.log("App-Proxy 启动成功！")
                        self?.log("代理进程 Bundle ID: com.demo.AppProxyDemo.AppProxyExtension")
                        self?.statusLabel.text = "代理：运行中"
                        self?.webView.reload()
                    } catch {
                        self?.log("启动隧道失败: \(error.localizedDescription)")
                        self?.statusLabel.text = "代理：启动失败"
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
                self?.statusLabel.text = "代理：未启动"
            }
        }
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url {
            log("请求开始: \(url.absoluteString)")
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            log("加载完成: \(url.absoluteString)")
            if url.absoluteString.contains("baidu.com") {
                log("✅ Rewrite 成功！example.com 已跳转到 baidu.com")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log("加载失败: \(error.localizedDescription)")
    }
    
    func log(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.logTextView.text += "[\(timestamp)] \(message)\n"
            let bottom = NSRange(location: self.logTextView.text.count - 1, length: 1)
            self.logTextView.scrollRangeToVisible(bottom)
        }
    }
}
