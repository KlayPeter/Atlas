# Atlas 下载与安装

[English](installation_en.md) · **简体中文**

## 发布状态

Atlas 当前已验证 Android release APK 的本地构建链，但 [GitHub Releases](https://github.com/KlayPeter/Atlas/releases) 尚未发布首个公开、正式签名的安装包。

- 想立即体验：按下文从源码构建 Android APK。
- 想等待正式包：Watch 或 Star 仓库，并关注 Releases 页面。
- iOS：可以从源码运行；原生 Share Extension 尚未完成，暂未提供 TestFlight 或 App Store 下载。

## Android：从源码构建

### 环境要求

- Flutter stable，Dart 3.11 或更新版本
- Android Studio、Android SDK 与 Java 17
- 一台 Android 设备或模拟器

### 构建 APK

```bash
git clone https://github.com/KlayPeter/Atlas.git
cd Atlas/apps/atlas_app
flutter pub get
flutter analyze
flutter build apk --release
```

输出文件：

```text
apps/atlas_app/build/app/outputs/flutter-apk/app-release.apk
```

通过 USB 安装：

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

> 当前 `android/app/build.gradle.kts` 使用 debug key 签名 release 构建，方便本地测试。请勿把它当作正式生产签名。公开分发或上架前，请配置独立 keystore，并安全保管签名材料。

## iOS：从源码运行

### 环境要求

- macOS 与最新稳定版 Xcode
- Flutter stable
- 可用的 Apple Development 签名身份

```bash
git clone https://github.com/KlayPeter/Atlas.git
cd Atlas/apps/atlas_app
flutter pub get
open ios/Runner.xcworkspace
```

在 Xcode 中选择 Team 和 Bundle Identifier，再运行到模拟器或真机。当前 iOS 可运行主应用，但从系统分享菜单导入文件仍需原生 Share Extension。

## 配置自己的 AI 模型

Atlas 不依赖 AI 也能阅读、搜索、保存进度和导出原文 HTML。需要解释、翻译、总结、问答、学习模式或可读版 HTML 时，在 App 的「设置 → AI 模型」中填写自己的模型配置。

- **API Key**：模型服务商发放给你的密钥。
- **Base URL**：模型服务商提供的 OpenAI 兼容 Chat Completions 接口地址，例如以 `/v1` 结尾的地址。
- **模型名称**：该 Key 可调用的模型名。

Atlas 把 API Key 存在系统安全存储。AI 请求会从设备直接发送到你填写的模型服务商，不经过 Atlas 的服务器。非本机 Base URL 必须使用 HTTPS。

仓库中的 `services/atlas_bff` 是供开发者研究或自行扩展的可选组件；当前 App 不需要部署或配置 BFF。

## 验证安装

1. 打开 Atlas，导入仓库中的 `docs/samples/mvp-markdown.md`。
2. 检查目录、全文搜索、代码块、表格和 Mermaid 渲染。
3. 滚动后退出并重新打开，确认恢复阅读进度。
4. 预览并分享原文 HTML。
5. 配置自己的 AI 模型后，再验证解释、总结、问答与学习模式。

完整流程见 [`mvp-verification.md`](mvp-verification.md)。
