// Generated from design/documents/*.md.
window.VexDocuments = {
  "thanks": {
    "name": "鸣谢.md",
    "file": "documents/ACKNOWLEDGEMENTS.md",
    "text": "# 鸣谢\n\n维刻 Vex · 写下想法，看见脉络。\n\n感谢每一位提出建议、报告问题、参与翻译和贡献代码的朋友。\n\n## 开源社区\n\n| 项目 | 在 Vex 中的用途 |\n| --- | --- |\n| Flutter / Dart | 应用框架与语言 |\n| Markdown 与编辑组件 | 文档解析、编辑与阅读 |\n| Mermaid | 流程图与时序图 |\n| KaTeX / mhchem | 原型中的数学与化学表达式 |\n| Cascadia Code | 代码字体 |\n| Noto Sans SC | 离线 PDF 的中文字体 |\n\n完整依赖与许可证见 [开源组件许可](Third-Party-Licenses.html)。各项目与字体遵循各自的许可证。\n\n## 关于项目\n\nVex Flutter 版沿用 Vex 的品牌与写作理念，以本地 Markdown 文件为中心。\n\n> 写下一个想法，再慢慢看清它与其他想法的联系。\n\n- 作者：沙漠尽头的狼 / CodeWF\n- [开源仓库](https://github.com/dotnet9/Vex-Flutter)\n- [CodeWF](https://codewf.com)\n\n```dart\nfinal thought = '写下想法';\nfinal structure = '看见脉络';\n```\n\nMIT License · Copyright © 2026 CodeWF\n"
  },
  "changelog": {
    "name": "更新日志.md",
    "file": "documents/CHANGELOG.md",
    "text": "# 更新日志（维刻 Vex）\n\n## 未发布（2026-10-17）\n\n- [新增] 文档水印，可设置文字与不透明度，正文显隐和导出包含分别控制，默认关闭。\n- [优化] 新手引导贴近目标，使用小三角气泡，缩短提示与操作之间的距离。\n- [优化] 品牌统一为「维刻 Vex」，沿用 V 图形和墨青配色，slogan 为「写下想法，看见脉络」。\n- [优化] 七类菜单和七类偏好设置；自动保存默认关闭，恢复草稿独立设置。\n- [优化] 代码块预留语言栏，聚焦与失焦保持布局稳定；Mermaid 支持展开源码与预览。\n- [优化] macOS 遵循系统习惯；手机单视图，平板最多双栏；鸿蒙覆盖手机、平板和电脑原型。\n- [优化] 鸣谢与更新日志使用随应用安装的 Markdown，不复制到用户目录；桌面独立只读窗口，手机和平板保留对话框。\n- [新增] MCP 本机服务设置、客户端配置、连接测试与审计的交互原型。\n\n## v0.2.2（2026-10-17）\n\n- [修复] GitHub Release 更新时的集成令牌权限错误。\n- [优化] 从 v0.2.2 源码重新构建安装包，发布前核对标签与源码提交，上传后验证 SHA-256。\n- [优化] 同名附件内容不一致时拒绝覆盖。\n- [保留] Windows 长文档源码视图的可见行布局与 Skia 渲染后端。\n\n## v0.2.1（2026-10-17）\n\n- [优化] Windows 源码视图按可见行布局，改善长文档滚动与内存占用。\n- [新增] 正文与导图演示、自定义标题栏、统一文档历史和四种界面语言。\n- [修复] Android SDK 初始化、Linux ARM64 工具链引导及 macOS 通用架构校验。\n- [新增] 自动测试、原生构建、安装包制作与完整性检查流程。\n- [优化] Android 使用固定发行证书与正式包名，每个安装包附 SHA-256 校验文件。\n\n---\n\nv0.2.1 与 v0.2.2 为历史开发预发布，日期以 [GitHub Releases](https://github.com/dotnet9/Vex-Flutter/releases) 为准，当时仅提供 Windows、macOS、Linux 和 Android 安装包，没有可安装的 IPA / HAP。\n\n“未发布”部分为本轮设计原型修订，不代表原生功能或安装包已经交付。后续六个平台均具备可安装版本后统一发布。\n"
  }
};
