# App-Proxy Demo 使用说明

## 项目概述
这是一个用于验证 iOS App-Proxy（Network Extension）技术可行性的 Demo 项目。
仅用于个人侧载测试，不上架 App Store。

## 项目结构
```
AppProxyDemo/
├── AppProxyDemo/              # 主App Target
│   ├── AppDelegate.swift      # 应用入口
│   ├── ViewController.swift   # 主界面（WKWebView + 控制面板 + 日志）
│   ├── Info.plist
│   └── AppProxyDemo.entitlements
├── AppProxyExtension/         # App-Proxy 扩展 Target（独立进程）
│   ├── AppProxyProvider.swift # 代理核心逻辑
│   ├── Info.plist
│   └── AppProxyExtension.entitlements
└── AppProxyDemo.xcodeproj/    # Xcode 项目
```

## 功能说明

### 主App界面
1. **App-Proxy 代理开关**：开启/关闭代理
2. **无缓存模式开关**：开启后禁用 WKWebView 缓存，强制所有请求走网络
3. **排除域名输入框**：填入不走代理的域名（逗号分隔），如 `github.com,cloudflare.com`
4. **测试 Rewrite 按钮**：访问 example.com，验证 URL 重定向能力
5. **清空日志按钮**：清空日志面板
6. **WKWebView 浏览器**：上半部分显示网页
7. **日志面板**：下半部分实时显示代理状态和请求日志

### 内置3条测试规则（硬编码）
1. **URL 重定向**：`example.com` → `baidu.com`
2. **请求头修改**：所有 HTTP 请求添加 `X-Proxy-Demo: Test123`，修改 User-Agent
3. **域名拦截**：`doubleclick.net`、`googlesyndication.com`、`googleadservices.com` 直接断开

## 使用前配置（必须）

### 1. 苹果开发者账号
- 需要付费开发者账号（$99/年）或企业证书
- 免费个人账号无法使用 Network Extension 能力

### 2. Xcode 配置步骤
1. 用 Xcode 打开 `AppProxyDemo.xcodeproj`
2. 选中项目 → Signing & Capabilities
3. 两个 Target 都需要：
   - 选择你的开发者 Team
   - Bundle Identifier 改成你自己的（如 `com.yourname.AppProxyDemo`）
   - 添加 Network Extensions capability，勾选 **App Proxy**
4. 前往 Apple Developer 后台：
   - 找到对应的 App ID
   - 确认 Network Extension（App-Proxy）权限已开启
   - 重新生成 Provisioning Profile
5. Xcode 中刷新描述文件

### 3. 修改 Bundle ID
代码中写死的 Bundle ID：
- 主App：`com.demo.AppProxyDemo`
- 扩展：`com.demo.AppProxyDemo.AppProxyExtension`

需要全局替换为你自己的 Bundle ID。

## 验证项（Demo 的核心目的）

运行后请验证以下5点：

### ✅ 验证1：代理能否启动
- 打开代理开关
- 日志显示「App-Proxy 启动成功」
- 状态标签显示「代理：运行中」

### ✅ 验证2：请求捕获率
- 浏览普通网页
- 日志中查看有多少请求被代理捕获
- 对比「有缓存」vs「无缓存模式」的捕获率差异

### ✅ 验证3：Rewrite 能力
- 点击「测试 Rewrite」按钮
- 观察 example.com 是否跳转到 baidu.com
- 注意：HTTPS 的 URL 重定向需要 MITM，Demo 仅对 HTTP 有效

### ✅ 验证4：请求头修改
- 访问 HTTP 网站（非HTTPS）
- 日志查看是否添加了自定义头

### ✅ 验证5：CF/GitHub 兼容性
- 访问 github.com、dash.cloudflare.com
- 观察是否触发人机验证、连接失败
- 在排除域名中填入这些域名，测试绕过方案是否有效

### ✅ 验证6：代理进程稳定性
- 切后台再切回前台
- 观察代理进程是否被系统回收
- 代理断开后能否自动恢复

## 已知限制
1. **不支持 HTTPS 解密（MITM）**：无法修改 HTTPS 响应内容
2. **HTTPS URL 重定向受限**：HTTPS 请求的 URL 重定向需要 MITM
3. **WKWebView 部分流量可能绕过代理**：WebKit 预连接、HTTP/2 连接池、缓存资源可能不走代理
4. **无圈X规则解析器**：3条规则硬编码，不支持导入订阅
5. **仅接管本App流量**：不影响手机其他App

## 下一步
如果 Demo 验证通过（大部分请求能被捕获、CF站点可通过排除域名绕过、代理进程稳定），再考虑集成到正式浏览器项目（v14.0）。

如果 Demo 验证失败（大量请求绕过代理、代理频繁崩溃），则放弃 App-Proxy 路线，继续使用 WKContentRuleList 域名拦截方案。
