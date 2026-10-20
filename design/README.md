# 设计原型

说明文档：[原型设计、预览与评审](../docs/design/原型设计.md)。本轮验证：[完整工作区改版、8 项体验调整与边界场景](Usability-Review.html)。

桌面顶部使用唯一视图入口，支持八种组合；底栏打开文件、大纲或文章信息，右侧统一承载大纲、文章信息与章节详情，窄窗口覆盖显示。文件栏不常用的折叠和列表操作归入“更多”。阅读限制行宽，编辑工具随编辑栏显示，保留明暗主题与墨青色配色。外观弹出层直接展示浅色、深色、跟随系统三个单选项，选择后立即生效并自动保存。界面改版已同步到 Flutter。

使用已有 Playwright 运行 `node design/scripts/verify-workspace-chrome.cjs` 可离屏验证视图切换、键盘焦点、辅助面板、实时统计、章节编辑与撤销，以及 800–1440 像素下的明暗布局。截图写入 `.dart_tool/prototype-workspace-chrome/`。

Flutter 对应回归位于 `apps/vex/test/workspace_chrome_test.dart`，覆盖八种视图、焦点恢复、实时信息、章节编辑与撤销、文档切换和覆盖面板；设置 `VEX_CHROME_CAPTURE_DIR` 可输出离屏截图。四语言与外观三态验证位于 `localization_test.dart`。

应用同步状态：[未实现需求记录](../docs/design/未实现需求记录.md)。对照记录：[桌面工作区验收](../docs/design/桌面工作区验收.md)。
