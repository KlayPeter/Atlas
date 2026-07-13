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

## 连接自己部署的 AI 后端

Atlas 不依赖 AI 也能阅读、搜索、保存进度和导出原文 HTML。需要解释、翻译、总结、问答、学习模式或可读版 HTML 时，再连接 Atlas BFF。

### 本地启动 BFF

```bash
cd Atlas/services/atlas_bff
bun install
cp .env.example .env
bun run typecheck
bun run start
```

编辑 `.env`：

```dotenv
APP_ENV=development
HOST=127.0.0.1
PORT=8787
OPENAI_API_KEY=your-api-key
OPENAI_MODEL=gpt-4.1-mini
```

然后在 App 的「设置 → AI 模型配置」中填写 BFF 地址。Android 模拟器通常使用 `http://10.0.2.2:8787`，iOS 模拟器通常使用 `http://127.0.0.1:8787`。

### 生产环境要求

- 使用 HTTPS 暴露 BFF。
- 设置 `APP_ENV=production`。
- 设置 `OPENAI_API_KEY`。
- 生成至少 32 个字符的 `ATLAS_BFF_ACCESS_TOKEN`，并在 App 中填写同一个值。
- 若允许用户传入 OpenAI 兼容 Base URL，将允许的 origin 写入 `AI_PROVIDER_BASE_URL_ALLOWLIST`，多个地址以逗号分隔。
- 不要在反向代理或应用日志中记录请求正文。

## 验证安装

1. 打开 Atlas，导入仓库中的 `docs/samples/mvp-markdown.md`。
2. 检查目录、全文搜索、代码块、表格和 Mermaid 渲染。
3. 滚动后退出并重新打开，确认恢复阅读进度。
4. 预览并分享原文 HTML。
5. 配置 BFF 后，再验证解释、总结、问答与学习模式。

完整流程见 [`mvp-verification.md`](mvp-verification.md)。
