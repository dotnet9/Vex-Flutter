# texweft
笺纬 Texweft · 落笔成文，思路成形。

使用 Flutter 原生渲染的 Markdown 写作空间，面向桌面、手机和平板。一个窗口共享即时编辑、源码、阅读和思维导图，以本地文件为中心。编辑体验参考 Typora，工作区功能与原型参考 [Vex](https://github.com/dotnet9/Vex)。

目前处于开发阶段。Windows 已完成原生 debug、release 构建与实际窗口运行，以及代码块、选区格式化、标题和列表输入的窗口集成验证，尚未发布正式安装包；其他平台、完整即时编辑体验、国际化、MCP 和视觉还原度仍在实现与验收中。当前状态见 [实现验收](docs/实现验收.md)，可评审的浏览器原型见 [design](design/README.md)。

## 源码结构

- `apps/texweft`：应用，采用 View / ViewModel、Repository / Service 分层。
- `packages/texweft_markdown_core`：纯 Dart 文档模型、保留源码的章节命令与统一历史。
- `packages/texweft_editor`：原生源码、即时编辑和阅读控件。
- `packages/texweft_mindmap`：与 Markdown 无关的通用思维导图控件。
- `design`：桌面、移动端和安装流程原型。
- `scripts`：从原型生成设计令牌、同步根目录品牌资源、准备离线导出字体。

应用使用 provider；独立控件通过 controller 与 callback 对外提供能力，不依赖应用状态。Markdown 原文为唯一数据来源。当前没有 WebView、SQLite、账户或云服务。

## 开发

官方工具链：Flutter 3.47.7 stable / Dart 3.13.5。仓库使用 Pub workspaces：

```powershell
flutter pub get
flutter analyze --no-pub
cd apps/texweft
flutter run -d windows
flutter test --no-pub
flutter test --no-pub integration_test/code_block_test.dart -d windows
flutter test --no-pub integration_test/typing_test.dart -d windows
```

三个独立包在各自目录执行 `dart test` 或 `flutter test --no-pub`。原生窗口集成测试使用内存文档与偏好，不读取个人笔记；设置 `TEXWEFT_CAPTURE_DIR` 环境变量可保存真实 Flutter 截图。

根目录 `logo.svg / logo.png / logo.ico` 是品牌源文件。修改后运行 `python scripts/sync_brand_assets.py` 同步各平台启动图标与应用资源（需要 Pillow），使用 `--check` 检查一致性。原型直接引用根目录 Logo。界面与中文沿用系统字体，仅代码内嵌约 0.92 MiB 的 Cascadia Code；现有离线 PDF 字体另占约 20.2 MiB，待单独优化。来源与许可见应用的 [字体说明](apps/texweft/assets/fonts/README.md)。

## 导出与发布

已接入 Markdown、独立 HTML、PDF、Word（OOXML）和完整导图 PNG 导出，以及系统打印入口。PDF 支持离线中文和长代码分页；复杂图片、嵌套列表、数学与图表仍需补齐和验证。

发布目标为 Windows 安装程序、macOS DMG、Linux DEB、Android APK 及符合 Apple、HarmonyOS 签名要求的分发包，不使用便携压缩包代替安装包。鸿蒙手机、平板和电脑需使用对应适配 SDK 与设备验证，不把概念原型计作系统适配完成。

MIT License · 沙漠尽头的狼 / CodeWF · [codewf.com](https://codewf.com)
