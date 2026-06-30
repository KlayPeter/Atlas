# Atlas MVP 验证说明

## 自动化检查

Flutter:

```sh
cd apps/atlas_app
flutter analyze
flutter test
```

Bun:

```sh
cd services/atlas_bff
bun run typecheck
bun test
```

## Demo 主流程

1. 启动 Bun BFF：

   ```sh
   cd services/atlas_bff
   bun run dev
   ```

2. 启动 Flutter App，必要时传入 BFF 地址：

   ```sh
   cd apps/atlas_app
   flutter run --dart-define=ATLAS_BFF_URL=http://127.0.0.1:8787
   ```

3. 在最近阅读页点击「打开文件」，导入 `docs/samples/mvp-markdown.md`。
4. 在阅读器验证标题、段落、列表、引用、代码块和表格渲染。
5. 点击目录并跳转章节。
6. 搜索 `local-first`，确认能定位结果。
7. 打开 AI 面板：
   - 粘贴一句文字并点击「解释」。
   - 点击「总结全文」。
   - 输入一个问题，确认问答内容逐步出现并保存到历史。
8. 点击「预览 HTML」，确认 WebView 能打开本地 HTML。
9. 点击「分享 HTML」，确认系统分享面板能调起。

## 外部分享导入

Android MVP 已在 `AndroidManifest.xml` 配置：

- `ACTION_VIEW` + `content://` + `text/*`
- `ACTION_SEND` + `text/*`
- `ACTION_SEND` / `ACTION_SEND_MULTIPLE` + `*/*`

分享进入 Atlas 后会走统一导入流程：复制到沙盒、hash 去重、跳转阅读器。

iOS 需要 Xcode 创建 Share Extension target，并配置 App Group、URL Scheme 和 extension `Info.plist`。当前 Flutter 侧已经接入 `receive_sharing_intent`，但 iOS 原生 target 尚未创建；真机验收前需要补齐这一步。

## 隐私检查

- 默认阅读、解析、HTML 转换都在本地完成。
- AI 请求只在用户主动打开 AI 面板并触发解释、总结或问答时发送。
- Flutter 侧发送给 BFF 的上下文限制为标题、大纲和最多 6000 字片段。
- BFF 请求日志只记录 method、path、status、duration，不记录原文。
- 开发环境没有 `OPENAI_API_KEY` 时返回 mock，便于本地 Demo。
