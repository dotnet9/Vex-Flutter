# Vex · Flutter 版本

本仓库是 [Vex](https://github.com/dotnet9/Vex) 的 Flutter 版本，仓库名为 `Vex-Flutter`，应用品牌为「维刻 Vex」，slogan 为「写下想法，看见脉络」。源码、原型与安装包的命名约定及应用身份变更见 [品牌命名与标识](docs/品牌命名与标识.md)。

使用 Flutter 原生渲染的 Markdown 写作空间，面向桌面、手机和平板。一个窗口共享即时编辑、源码、阅读和思维导图，以本地文件为中心。编辑体验参考 Typora，产品定位与工作流沿用 Vex。

目前处于开发阶段。Windows 已完成原生 debug、release 构建、实际窗口运行与安装卸载验证，以及代码块、选区格式化、标题和列表输入的窗口集成验证；Android 已完成三架构 production APK 的发行签名构建与身份校验，早前预览包通过模拟器工作区与四语言切换测试。多平台安装包交给 GitHub Actions 构建发布；跨平台真机、完整即时编辑体验、MCP 和视觉还原度仍在实现与验收中。当前状态见 [实现验收](docs/实现验收.md)，可评审的浏览器原型见 [design](design/README.md)。

界面支持简体中文、繁体中文、英语、日语；在设置中即时切换并保存，首次启动匹配系统语言。菜单、对话框、布局与排版选择、提示、引导及内置示例采用官方 ARB 本地化，切换界面语言保留文档与撤销历史。独立编辑器与导图包允许宿主注入翻译。详见 [国际化](docs/国际化.md)。

## 源码结构

- `apps/vex`：应用，采用 View / ViewModel、Repository / Service 分层。
- `packages/vex_markdown_core`：纯 Dart 文档模型、保留源码的章节命令与统一历史。
- `packages/vex_editor`：原生源码、即时编辑和阅读控件。
- `packages/vex_mindmap`：与 Markdown 无关的通用思维导图控件。
- `design`：桌面、移动端和安装流程原型。
- `scripts`：从原型生成设计令牌、同步根目录品牌资源、准备离线导出字体。

应用使用 provider；独立控件通过 controller 与 callback 对外提供能力，不依赖应用状态。Markdown 原文为唯一数据来源。当前没有 WebView、SQLite、账户或云服务。

## 开发

官方工具链：Flutter 3.47.7 stable / Dart 3.13.5。仓库使用 Pub workspaces：

```powershell
flutter pub get
flutter analyze --no-pub
cd apps/vex
flutter run -d windows
flutter test --no-pub
flutter test --no-pub integration_test/code_block_test.dart -d windows
flutter test --no-pub integration_test/typing_test.dart -d windows
```

三个独立包在各自目录执行 `dart test` 或 `flutter test --no-pub`。原生窗口集成测试使用内存文档与偏好，不读取个人笔记；设置 `VEX_CAPTURE_DIR` 环境变量可保存真实 Flutter 截图。

根目录 `logo.svg / logo.png / logo.ico` 是品牌源文件。修改后运行 `python scripts/sync_brand_assets.py` 同步各平台启动图标与应用资源（需要 Pillow），使用 `--check` 检查一致性。原型直接引用根目录 Logo。界面与中文沿用系统字体，仅代码内嵌约 0.92 MiB 的 Cascadia Code；离线 PDF 字体无损压缩后约 12.1 MiB，导出时才解压。来源与许可见应用的 [字体说明](apps/vex/assets/fonts/README.md)。

## 导出与发布

已接入 Markdown、独立 HTML、PDF、Word（OOXML）和完整导图 PNG 导出，以及系统打印入口。PDF 支持离线中文和长代码分页；复杂图片、嵌套列表、数学与图表仍需补齐和验证。

发布目标为 Windows 安装程序、macOS DMG、Linux DEB、Android APK 及符合 Apple、HarmonyOS 签名要求的分发包，不使用便携压缩包代替安装包。鸿蒙手机、平板和电脑需使用对应适配 SDK 与设备验证，不把概念原型计作系统适配完成。

`v0.2.1` 起通过 GitHub Actions 按 tag 构建安装包：Windows x64 EXE、macOS Intel / Apple 芯片通用 DMG、Linux x64 / ARM64 DEB、Android 三架构正式签名 APK，并生成 SHA-256 校验文件。iOS 当前仅接入 macOS runner 编译检查，IPA 与鸿蒙 HAP 尚缺签名或适配条件。详见 [安装包与自动发布](docs/安装包与自动发布.md)，产物以 [GitHub Releases](https://github.com/dotnet9/Vex-Flutter/releases) 的实际构建结果为准。

MIT License · 沙漠尽头的狼 / CodeWF · [codewf.com](https://codewf.com)
