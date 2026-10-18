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
    "text": "# 更新日志（维刻 Vex）\n\n## v0.3.1 及后续改进（2026-10-18）\n\n### 待发布改进\n\n- 写作区延伸到窗口底部，只保留简洁的侧边栏、源码切换和词数；文件列表可切换目录树与摘要列表，大纲可独立搜索。\n- 修正 Windows 源码行号对齐、斜体字形重叠和即时编辑方向键移动；减少点击代码块、列表时的页面跳动。\n- 代码块支持多种语言高亮，可按语言名称或简称搜索，例如 C#、JS、Python。\n- 导图滚轮默认平移，Ctrl + 滚轮缓慢缩放；Enter 添加同级、Tab 添加子级、F2 改名，新增节点可立即输入标题。\n- 界面主题色与正文排版分开设置，浅色正文使用白底，深色模式照顾正文阅读；排版面板直接预览四级标题。\n- 提高 Windows 安装界面的文字对比度和操作图标清晰度，新安装默认放在 `%LOCALAPPDATA%\\Programs\\Vex` 目录。\n\n### 本日已发布\n\n- [新增] 统一维刻 Vex 品牌、墨青 Logo、各平台应用身份和安装包；提供 Windows、macOS、Linux 和 Android 公开下载。\n- [新增] 六种导图结构、章节原位编辑、表格及 Markdown 元素菜单、原生数学 / 化学公式与 Mermaid 图表。\n- [新增] 文档和导出水印独立设置；桌面本机 MCP 服务、客户端配置及安全确认。\n- [优化] 默认关闭自动保存，恢复草稿独立控制；保护输入法候选、保存期间的新增输入及重复关闭操作。\n- [优化] 打开文件自动加载所在目录及子目录中的 Markdown 树，跨目录切换时恢复对应目录。\n- [优化] 大文档后台解析、结构索引缓存和按需布局；修复章节跳转位移与滚动时文字延迟绘制。\n- [优化] 自适应布局、真实光标居中的打字机模式、专注模式、独立只读内置文档和偏好设置。\n- [优化] 修复 Windows 安装包构建问题，提供可下载安装的 v0.3.1；每份安装包均附完整性校验文件。\n\n本节合并同日的 v0.3.0、v0.3.1 记录。上面的“待发布改进”尚未进入已下载的 v0.3.1 安装包。\n\n0.x 仍是早期版本，跨平台真机、输入法和复杂排版需继续验收；iOS / HarmonyOS 安装包暂缓。\n\n## v0.2.2（2026-10-17）\n\n- 改善 Windows 长文档源码视图的滚动和内存占用。\n- 提供正文与导图演示、自定义标题栏、统一撤销记录和四种界面语言。\n- 完善 Windows、macOS、Linux 和 Android 安装包的构建与下载校验。\n- 设计原型补充文档水印、紧邻目标的新手引导、手机单视图和平板双栏，以及 MCP 设置等交互。\n- 鸣谢与更新日志随应用安装，不复制到个人文档目录；桌面使用独立只读窗口，手机和平板使用对话框。\n\n---\n\nv0.2.1 与 v0.2.2 为历史开发预发布，日期以 [GitHub Releases](https://github.com/dotnet9/Vex-Flutter/releases) 为准，当时仅提供 Windows、macOS、Linux 和 Android 安装包，没有可安装的 IPA / HAP。\n\n本节合并同日 v0.2.1、v0.2.2 及设计原型记录；原型不代表功能已经交付。实际安装包和校验文件以对应 GitHub Release 为准。\n"
  }
};
